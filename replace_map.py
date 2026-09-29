import re

with open('/Users/abhyudaytaneja/Downloads/EVCS/index.html', 'r') as f:
    content = f.read()

# Find the start of GoogleMapComponent
start_marker = "const GoogleMapComponent = ({ buses, routes, height = \"600px\", onRouteCalculated }) => {"
end_marker = "// FLEET TABLE (unchanged)"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker, start_idx)

if start_idx != -1 and end_idx != -1:
    new_component = """const GoogleMapComponent = ({ buses, routes, height = "600px", onRouteCalculated }) => {
            const mapRef = useRef(null);
            const mapInstanceRef = useRef(null);
            const markersRef = useRef({});
            const polylinesRef = useRef({});

            useEffect(() => {
                if (mapInstanceRef.current || !mapRef.current) return;
                
                // Wait for L to be available
                if (!window.L) {
                    console.error("Leaflet not loaded");
                    return;
                }

                const initialCenter = buses.length === 1 ? buses[0].location : DELHI_CENTER;
                const initialZoom = buses.length === 1 ? 14 : 11;
                
                const map = L.map(mapRef.current).setView([initialCenter.lat, initialCenter.lng], initialZoom);
                
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© OpenStreetMap contributors',
                    maxZoom: 19
                }).addTo(map);
                
                mapInstanceRef.current = map;
            }, []);

            // Route Calculation (using OSRM instead of Google Directions)
            useEffect(() => {
                if (!mapInstanceRef.current) return;
                
                routes.forEach(async route => {
                    if (polylinesRef.current[route.id]) return;
                    
                    try {
                        // OSRM expects Lng,Lat
                        const coordinates = route.points.map(p => `${p.lng},${p.lat}`).join(';');
                        const res = await fetch(`https://router.project-osrm.org/route/v1/driving/${coordinates}?overview=full&geometries=geojson`);
                        const data = await res.json();
                        
                        if (data.code === 'Ok' && data.routes && data.routes[0]) {
                            // OSRM returns GeoJSON coordinates as [lng, lat]
                            const detailedPath = data.routes[0].geometry.coordinates.map(c => ({ lat: c[1], lng: c[0] }));
                            if (onRouteCalculated) onRouteCalculated(route.id, detailedPath);
                            
                            // Draw polyline
                            polylinesRef.current[route.id] = L.polyline(detailedPath, {
                                color: route.color,
                                weight: 5,
                                opacity: 0.8
                            }).addTo(mapInstanceRef.current);
                        } else {
                            throw new Error("OSRM failed");
                        }
                    } catch (err) {
                        console.log("Using fallback straight lines", err);
                        polylinesRef.current[route.id] = L.polyline(route.points, {
                            color: route.color,
                            weight: 4,
                            opacity: 0.8,
                            dashArray: '10, 10'
                        }).addTo(mapInstanceRef.current);
                    }
                });
            }, [routes]);

            // Bus Markers Update
            useEffect(() => {
                if (!mapInstanceRef.current || !window.L) return;
                
                buses.forEach(bus => {
                    const color = bus.status === 'Alert' ? '#EF4444' : bus.status === 'Charging' ? '#10B981' : '#3B82F6';
                    
                    // HTML Icon
                    const svgIcon = L.divIcon({
                        className: 'custom-bus-marker',
                        html: `<div style="background-color: ${color}; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3); color: white;">
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6v6"/><path d="M15 6v6"/><path d="M2 12h19.6"/><path d="M18 18h3s.5-1.7.8-2.8c.1-.4.2-.8.2-1.2 0-.4-.1-.8-.2-1.2l-1.4-5C20.1 6.8 19.1 6 18 6H4a2 2 0 0 0-2 2v10h3"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/></svg>
                        </div>`,
                        iconSize: [28, 28],
                        iconAnchor: [14, 14],
                        popupAnchor: [0, -14]
                    });

                    function getPopupHtml(data) {
                        return `<div style="font-family:sans-serif;min-width:140px;">
                                <div style="font-weight:bold;font-size:14px;margin-bottom:6px;color:#1e293b;border-bottom:1px solid #eee;padding-bottom:4px;">${data.id}</div>
                                <div style="font-size:12px;color:#64748b;line-height:1.5;">
                                    <div style="display:flex;justify-content:space-between;"><span>Speed:</span><span style="color:#0f172a;font-weight:600;">${Math.round(data.speed)} km/h</span></div>
                                    <div style="display:flex;justify-content:space-between;"><span>Battery:</span><span style="color:${data.soc < 20 ? '#ef4444' : '#10b981'};font-weight:600;">${Math.round(data.soc)}%</span></div>
                                    <div style="display:flex;justify-content:space-between;"><span>Status:</span><span style="color:${data.status === 'Moving' ? '#3b82f6' : '#64748b'};font-weight:600;">${data.status}</span></div>
                                </div>
                            </div>`;
                    }

                    if (markersRef.current[bus.id]) {
                        markersRef.current[bus.id].setLatLng([bus.location.lat, bus.location.lng]);
                        markersRef.current[bus.id].setIcon(svgIcon);
                        const popup = markersRef.current[bus.id].getPopup();
                        if (popup && popup.isOpen()) {
                            markersRef.current[bus.id].setPopupContent(getPopupHtml(bus));
                        }
                    } else {
                        const marker = L.marker([bus.location.lat, bus.location.lng], { icon: svgIcon })
                            .addTo(mapInstanceRef.current)
                            .bindPopup(getPopupHtml(bus));
                        
                        marker.on('mouseover', function (e) { this.openPopup(); });
                        marker.on('mouseout', function (e) { this.closePopup(); });
                        
                        markersRef.current[bus.id] = marker;
                    }
                });
                
                if (buses.length === 1) {
                    mapInstanceRef.current.panTo([buses[0].location.lat, buses[0].location.lng]);
                }
            }, [buses]);

            return <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden relative" style={{ height }}><div ref={mapRef} style={{ width: '100%', height: '100%', zIndex: 1 }} id="leaflet-map" /></div>;
        };

        // ─────────────────────────────────────────────────────────────────────
        """
    
    new_content = content[:start_idx] + new_component + content[end_idx-1:]
    
    with open('/Users/abhyudaytaneja/Downloads/EVCS/index.html', 'w') as f:
        f.write(new_content)
    print("Map successfully replaced!")
else:
    print("Could not find markers")
