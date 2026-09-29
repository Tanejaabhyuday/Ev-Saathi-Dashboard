import re

with open('/Users/abhyudaytaneja/Downloads/EVCS/EVSaathi-iOS/EVSaathiSrc/ViewModels/FleetViewModel.swift', 'r') as f:
    content = f.read()

start_str = "var updatedBuses: [BusModel] = []"

if start_str in content:
    replacement = """var updatedBuses: [BusModel] = []

        // Enforce at least 2 buses charging
        let chargingCount = buses.filter { $0.status == .charging || $0.status == .idle || $0.soc <= 0 }.count
        if chargingCount < 2 {
            var movingBuses = buses.enumerated().filter { $0.element.status == .moving && $0.element.soc > 0 }
            movingBuses.sort { $0.element.soc < $1.element.soc }
            for i in 0..<min(2 - chargingCount, movingBuses.count) {
                buses[movingBuses[i].offset].soc = 0
            }
        }"""
    
    new_content = content.replace(start_str, replacement)
    with open('/Users/abhyudaytaneja/Downloads/EVCS/EVSaathi-iOS/EVSaathiSrc/ViewModels/FleetViewModel.swift', 'w') as f:
        f.write(new_content)
    print("Successfully updated iOS simulation!")
else:
    print("Start not found.")
