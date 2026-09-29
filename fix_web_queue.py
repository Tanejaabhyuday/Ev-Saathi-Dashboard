import re

with open('/Users/abhyudaytaneja/Downloads/EVCS/index.html', 'r') as f:
    content = f.read()

# 1. Add CHARGER_LOCATIONS globally
if "const CHARGER_LOCATIONS" not in content:
    config_marker = "const DELHI_CENTER"
    replacement1 = """const CHARGER_LOCATIONS = { "CH-1": { lat: 28.5494, lng: 77.2522 }, "CH-2": { lat: 28.4900, lng: 77.0886 }, "CH-3": { lat: 28.5708, lng: 77.3216 }, "CH-4": { lat: 28.5524, lng: 77.0583 } };
        const DELHI_CENTER"""
    content = content.replace(config_marker, replacement1)

# 2. Add chargersRef to App
if "chargersRef" not in content:
    ref_marker = "const firedAlertsRef = useRef(new Set());"
    replacement2 = """const firedAlertsRef = useRef(new Set());
            const chargersRef = useRef([]);
            useEffect(() => { chargersRef.current = chargers; }, [chargers]);"""
    content = content.replace(ref_marker, replacement2)

# 3. Replace the setInterval logic
start_str = "setBuses(prevBuses => {"
end_str = "// Batch-write all bus positions to Firestore"

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    new_interval_logic = """setBuses(prevBuses => {
                        let chargingCount = prevBuses.filter(b => ['Charging', 'Idle'].includes(b.status) || b.soc <= 0).length;
                        if (chargingCount < 2) {
                            const movingBuses = prevBuses.filter(b => b.status === 'Moving' && b.soc > 0).sort((a, b) => a.soc - b.soc);
                            for (let i = 0; i < Math.min(2 - chargingCount, movingBuses.length); i++) {
                                movingBuses[i].soc = 0; // Force to charge
                            }
                        }

                        let localChargers = JSON.parse(JSON.stringify(chargersRef.current));
                        const chargersToUpdate = {};
                        
                        const updatedBuses = prevBuses.map(bus => {
                            const detailedPath = detailedRoutes[bus.routeId];
                            const basicRoute = ROUTES.find(r => r.id === bus.routeId);

                            if (bus.status !== 'Moving') {
                                if (bus.status === 'Charging') {
                                    const newSoc = Math.min(100, bus.soc + 0.5);
                                    if (newSoc >= 95) {
                                        const cIdx = localChargers.findIndex(c => c.currentVehicle === bus.id);
                                        if (cIdx !== -1) {
                                            localChargers[cIdx].isOccupied = false;
                                            localChargers[cIdx].currentVehicle = null;
                                            chargersToUpdate[localChargers[cIdx].id] = localChargers[cIdx];
                                        }
                                        let bPath = detailedPath?.length > 0 ? detailedPath : basicRoute.points;
                                        let idx = detailedPath?.length > 0 ? bus.pathIndex : bus.targetIndex;
                                        idx = idx % bPath.length;
                                        return { ...bus, soc: newSoc, status: 'Moving', speed: 0, location: bPath[idx], latitude: bPath[idx].lat, longitude: bPath[idx].lng };
                                    }
                                    return { ...bus, soc: newSoc, speed: 0 };
                                } else if (bus.status === 'Idle' && bus.soc <= 0) {
                                    const freeCIdx = localChargers.findIndex(c => !c.isOccupied);
                                    if (freeCIdx !== -1) {
                                        localChargers[freeCIdx].isOccupied = true;
                                        localChargers[freeCIdx].currentVehicle = bus.id;
                                        chargersToUpdate[localChargers[freeCIdx].id] = localChargers[freeCIdx];
                                        const loc = CHARGER_LOCATIONS[localChargers[freeCIdx].id];
                                        return { ...bus, status: 'Charging', speed: 0, location: loc, latitude: loc.lat, longitude: loc.lng };
                                    }
                                }
                                return { ...bus, speed: 0 };
                            }

                            let newLocation = { ...bus.location };
                            let nextPathIndex = bus.pathIndex;
                            let nextTargetIndex = bus.targetIndex;

                            if (detailedPath && detailedPath.length > 0) {
                                nextPathIndex = (bus.pathIndex + 1) % detailedPath.length;
                                newLocation = detailedPath[nextPathIndex];
                            } else if (basicRoute) {
                                const target = basicRoute.points[bus.targetIndex % basicRoute.points.length];
                                const dLat = target.lat - bus.location.lat;
                                const dLng = target.lng - bus.location.lng;
                                const dist = Math.sqrt(dLat * dLat + dLng * dLng);
                                if (dist < 0.001) {
                                    nextTargetIndex = (bus.targetIndex + 1) % basicRoute.points.length;
                                } else {
                                    newLocation = { lat: bus.location.lat + dLat * 0.05, lng: bus.location.lng + dLng * 0.05 };
                                }
                            }

                            const overSpeed = Math.random() > 0.95;
                            let newSpeed = overSpeed ? 65 + Math.random() * 20 : 30 + Math.random() * 20;
                            const newTemp = 35 + (newSpeed / 10) + Math.random();
                            let newSoc = Math.max(0, bus.soc - 0.05);
                            let newStatus = 'Moving';
                            
                            if (newSoc <= 0) {
                                newSpeed = 0;
                                const freeCIdx = localChargers.findIndex(c => !c.isOccupied);
                                if (freeCIdx !== -1) {
                                    newStatus = 'Charging';
                                    localChargers[freeCIdx].isOccupied = true;
                                    localChargers[freeCIdx].currentVehicle = bus.id;
                                    chargersToUpdate[localChargers[freeCIdx].id] = localChargers[freeCIdx];
                                    newLocation = CHARGER_LOCATIONS[localChargers[freeCIdx].id];
                                } else {
                                    newStatus = 'Idle';
                                }
                            }

                            const tempKey = `${bus.id}_temp`;
                            const speedKey = `${bus.id}_speed`;
                            const socKey = `${bus.id}_soc`;

                            if (newTemp > 45 && !firedAlertsRef.current.has(tempKey)) {
                                firedAlertsRef.current.add(tempKey);
                                const id = generateId();
                                db.collection('alerts').doc(id).set({
                                    id, busId: bus.id, type: 'temp',
                                    message: `High Battery Temp: ${Math.round(newTemp)}°C on ${bus.id}`,
                                    timestamp: firebase.firestore.FieldValue.serverTimestamp(),
                                    resolved: false
                                });
                            }
                            if (newSpeed > 60 && !firedAlertsRef.current.has(speedKey)) {
                                firedAlertsRef.current.add(speedKey);
                                const id = generateId();
                                db.collection('alerts').doc(id).set({
                                    id, busId: bus.id, type: 'speed',
                                    message: `Overspeed: ${Math.round(newSpeed)} km/h on ${bus.id}`,
                                    timestamp: firebase.firestore.FieldValue.serverTimestamp(),
                                    resolved: false
                                });
                            }
                            if (newSoc < 15 && !firedAlertsRef.current.has(socKey)) {
                                firedAlertsRef.current.add(socKey);
                                const id = generateId();
                                db.collection('alerts').doc(id).set({
                                    id, busId: bus.id, type: 'soc',
                                    message: `Low Battery: ${Math.round(newSoc)}% on ${bus.id}`,
                                    timestamp: firebase.firestore.FieldValue.serverTimestamp(),
                                    resolved: false
                                });
                            }

                            return {
                                ...bus,
                                location: newLocation,
                                latitude: newLocation.lat,
                                longitude: newLocation.lng,
                                pathIndex: nextPathIndex,
                                targetIndex: nextTargetIndex,
                                speed: newSpeed, soc: newSoc, temp: newTemp,
                                status: newStatus
                            };
                        });

                        const batch = db.batch();
                        updatedBuses.forEach(bus => {
                            batch.set(db.collection('buses').doc(bus.id), bus);
                        });
                        Object.values(chargersToUpdate).forEach(c => {
                            batch.set(db.collection('chargers').doc(c.id), c);
                        });
                        batch.commit();

                        return updatedBuses;
                    });
                }, REFRESH_RATE);

                return () => clearInterval(interval);"""
    
    # We replace from start_idx up to the end of the batch.commit() inside the interval
    # The original ends with:
    # batch.commit();
    # return updatedBuses;
    # });
    # }, REFRESH_RATE);
    # return () => clearInterval(interval);
    
    # Let's find the end of the interval block to replace it entirely
    interval_end_idx = content.find("return () => clearInterval(interval);", end_idx)
    if interval_end_idx != -1:
        interval_end_idx += len("return () => clearInterval(interval);")
        new_content = content[:start_idx] + new_interval_logic + content[interval_end_idx:]
        with open('/Users/abhyudaytaneja/Downloads/EVCS/index.html', 'w') as f:
            f.write(new_content)
        print("Successfully updated web simulation!")
    else:
        print("Interval end not found.")
else:
    print("Start or end not found")
