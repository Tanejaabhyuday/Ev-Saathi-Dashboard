import re

with open('/Users/abhyudaytaneja/Downloads/EVCS/index.html', 'r') as f:
    content = f.read()

start_str = "onClick={() => {"
end_str = "Scatter Fleet"

# Need to find the exact button location
btn_idx = content.find("Randomize fleet positions")
if btn_idx != -1:
    start_idx = content.rfind("onClick={() => {", 0, btn_idx)
    end_idx = content.find("</button>", btn_idx)
    
    if start_idx != -1 and end_idx != -1:
        new_btn = """onClick={() => {
                                            if(!window.confirm("Randomize fleet positions and batteries?")) return;
                                            const batch = db.batch();
                                            const scatteredBuses = buses.map((bus, i) => {
                                                const dPath = detailedRoutes[bus.routeId];
                                                const bRoute = ROUTES.find(r => r.id === bus.routeId);
                                                let pIdx = bus.pathIndex, lat = bus.location.lat, lng = bus.location.lng;
                                                
                                                if (dPath && dPath.length > 0) {
                                                    pIdx = Math.floor(Math.random() * dPath.length);
                                                    lat = dPath[pIdx].lat; lng = dPath[pIdx].lng;
                                                } else if (bRoute) {
                                                    pIdx = Math.floor(Math.random() * bRoute.points.length);
                                                    lat = bRoute.points[pIdx].lat; lng = bRoute.points[pIdx].lng;
                                                }
                                                const newSoc = Math.floor(Math.random() * 90) + 5;
                                                
                                                batch.update(db.collection('buses').doc(bus.id), {
                                                    soc: newSoc,
                                                    pathIndex: pIdx,
                                                    targetIndex: pIdx,
                                                    latitude: lat,
                                                    longitude: lng,
                                                    status: 'Moving',
                                                    speed: 40 + Math.random() * 20
                                                });
                                                
                                                return {
                                                    ...bus,
                                                    soc: newSoc,
                                                    pathIndex: pIdx,
                                                    targetIndex: pIdx,
                                                    location: { lat, lng },
                                                    status: 'Moving',
                                                    speed: 40 + Math.random() * 20
                                                };
                                            });
                                            
                                            chargers.forEach(c => {
                                                batch.update(db.collection('chargers').doc(c.id), { isOccupied: false, currentVehicle: null });
                                            });
                                            
                                            batch.commit().then(() => {
                                                setBuses(scatteredBuses);
                                            });
                                        }}
                                        className="mr-2 text-xs font-semibold bg-indigo-100 text-indigo-700 px-3 py-1.5 rounded-full hover:bg-indigo-200 transition-colors"
                                    >
                                        Scatter Fleet
                                    """
        new_content = content[:start_idx] + new_btn + content[end_idx:]
        with open('/Users/abhyudaytaneja/Downloads/EVCS/index.html', 'w') as f:
            f.write(new_content)
        print("Fixed scatter fleet!")
    else:
        print("Indices not found")
else:
    print("Button not found")
