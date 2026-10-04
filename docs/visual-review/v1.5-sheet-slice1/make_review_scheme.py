"""Create/remove a temporary DEV scheme including the UI test target.

Run from this checkout only. Does not modify an existing scheme or signing.
"""
from pathlib import Path
import sys
from xml.etree import ElementTree as ET

repo = Path(__file__).resolve().parents[3]
schemes = repo / "traders_guild.xcodeproj/xcshareddata/xcschemes"
output = schemes / "Slice1 Fixture Review.xcscheme"
if "--remove" in sys.argv:
    output.unlink(missing_ok=True)
else:
    tree = ET.parse(schemes / "traders_guild LinkedDev.xcscheme")
    testable = ET.SubElement(tree.getroot().find("TestAction/Testables"),
                             "TestableReference", {"skipped": "NO", "parallelizable": "NO"})
    ET.SubElement(testable, "BuildableReference", {
        "BuildableIdentifier": "primary", "BlueprintIdentifier": "D60EC7892E280DB3005E2FF1",
        "BuildableName": "traders_guildUITests.xctest", "BlueprintName": "traders_guildUITests",
        "ReferencedContainer": "container:traders_guild.xcodeproj",
    })
    tree.write(output, encoding="utf-8", xml_declaration=True)
    print(output)
