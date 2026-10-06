"""Write and validate proposed house reservations; never modify gameplay geometry."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "docs/house"


def overlap(a, b):
    return max(0, min(a[2], b[2])-max(a[0], b[0])) * max(0, min(a[3], b[3])-max(a[1], b[1]))


def main():
    rooms = [
        {"id":"bedroom", "bounds":[-6.3,.6,-1.5,4.9], "status":"retained"},
        {"id":"hall", "bounds":[-1.5,.6,1.5,4.9], "status":"retained"},
        {"id":"living", "bounds":[1.5,-4.9,6.3,4.9], "status":"retained_open_kitchen_living"},
        {"id":"bathroom", "bounds":[-6.3,-4.9,-4.1,-1.5], "status":"proposed_bath_laundry"},
        {"id":"backhall", "rectangles":[[-6.3,-1.5,1.5,.6],[-4.1,-4.9,1.5,-1.5]], "status":"retained_circulation_with_proposed_partition"}
    ]
    connections = [
        {"id":"front", "connects":["exterior","hall"], "center_xz":[0,4.9], "width_m":1.3, "height_m":2.3, "status":"existing"},
        {"id":"bedroom", "connects":["hall","bedroom"], "center_xz":[-1.5,2.8], "width_m":1.3, "height_m":2.3, "status":"existing"},
        {"id":"living", "connects":["hall","living"], "center_xz":[1.5,2.8], "width_m":1.3, "height_m":2.3, "status":"existing"},
        {"id":"backhall", "connects":["hall","backhall"], "center_xz":[0,.6], "width_m":1.3, "height_m":2.3, "status":"existing"},
        {"id":"kitchen_passage", "connects":["living","backhall"], "center_xz":[1.5,-1.4], "width_m":1.6, "height_m":2.4, "status":"existing_open_passage"},
        {"id":"bathroom", "connects":["backhall","bathroom"], "center_xz":[-5.25,-1.5], "width_m":1.3, "height_m":2.3, "status":"proposed"}
    ]
    reservations = [
        {"id":"north_kitchen", "bounds":[3.1,-4.84,6.14,-4.19], "status":"cabinet_envelope"},
        {"id":"fridge", "bounds":[1.9,-4.84,2.65,-4.09], "status":"appliance_envelope"},
        {"id":"stove", "bounds":[5.0,-1.65,5.8,-.75], "status":"provisional_model_envelope"},
        {"id":"hearth", "bounds":[4.7,-2,6.1,-.4], "status":"provisional_hearth_envelope"},
        {"id":"entry_bench", "bounds":[-1.30,3.55,-.85,4.55], "status":"provisional_storage_envelope"}
    ]
    stair = [-3.9,-3.325,.85,-2.225]
    data = {"schema_version":1, "status":"implemented_first_asset_batch", "project":"F:/Workspace/run",
            "coordinate_contract":{"coordinates":"house_local_meters", "up_axis":"Y", "front_axis":"+Z",
                "planning_resolution_m":.1, "exception":"Preserve exact authored stair coordinates; do not snap existing geometry.",
                "grid_scale_applied":False},
            "ground_floor":{"y_elevation_m":0, "clear_height_m":3.15, "footprint":[-6.3,-4.9,6.3,4.9],
                "rooms":rooms,"connections":connections,"reservations":reservations,
                "stair_void":{"bounds":stair,"lower_floor_m":-3.4,"width_m":1.1,"risers":19,"status":"existing_preserve"}},
            "cellar":{"status":"existing_preserve_geometry_rooms_notes_and_audio"},
            "route_reservations":[{"id":"west_service_approach","bounds":[-6.24,-1.44,1.44,.54]},
                                   {"id":"common_room_spine","bounds":[1.56,-3.9,3.06,4.7]}]}
    rectangles=[]
    for room in rooms:
        rectangles += [(room["id"], b) for b in room.get("rectangles",[room.get("bounds")])]
    area=0
    for i,(id,b) in enumerate(rectangles):
        assert b[0]<b[2] and b[1]<b[3]
        assert b[0]>=-6.3 and b[1]>=-4.9 and b[2]<=6.3 and b[3]<=4.9
        area += (b[2]-b[0])*(b[3]-b[1])
        for other,c in rectangles[i+1:]:
            assert overlap(b,c)<1e-8, (id,other)
    assert abs(area-12.6*9.8)<1e-8, area
    bath=next(r["bounds"] for r in rooms if r["id"]=="bathroom")
    assert overlap(bath,stair)==0, "Bathroom cuts stair void"
    assert bath[0] < -5.25-.65 and -5.25+.65 < bath[2], "Door exceeds bathroom wall"
    graph={id:set() for id in [r["id"] for r in rooms]+["exterior"]}
    for c in connections:
        a,b=c["connects"]; graph[a].add(b);graph[b].add(a)
    reached={"exterior"};pending=["exterior"]
    while pending:
        for id in graph[pending.pop()]-reached:
            reached.add(id);pending.append(id)
    assert reached==set(graph)
    for reservation in reservations:
        for route in data["route_reservations"]:
            assert overlap(reservation["bounds"],route["bounds"])<1e-8,(reservation["id"],route["id"])
    DEST.mkdir(parents=True,exist_ok=True)
    (DEST/"refined_layout.json").write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    render(data)
    print(f"PLAN PASS: {area:.2f} mÂ² covered, no room overlaps, all 5 zones connected, stair void retained, fixture envelopes outside reserved routes.")


def render(data):
    def p(x,z):return (130+(x+6.3)*60,245+(z+4.9)*60)
    svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1050" viewBox="0 0 1400 1050">',
         '<rect width="1400" height="1050" fill="#111f2b"/>',
         '<style>text{font-family:Segoe UI,Arial,sans-serif;fill:#ecdfbf}.small{font-size:14px;fill:#91a8b5}.wall{stroke:#ecdfbf;stroke-width:7;fill:none}</style>',
         '<text x="75" y="70" class="small">OPHELIAS DREAM Â· F:\\Workspace\\run Â· DOMESTIC REFINEMENT / FIRST BATCH / 01</text>',
         '<text x="75" y="125" font-size="34" letter-spacing="3">A HOME THAT MAKES SENSE</text>',
         '<text x="75" y="164" class="small">Existing footprint and cellar retained Â· bathroom/laundry tucked beside the stair Â· cold storm / warm local hearth</text>']
    colors={"bedroom":"#454952","hall":"#514b40","living":"#574634","backhall":"#344854","bathroom":"#436269"}
    for room in data["ground_floor"]["rooms"]:
        for b in room.get("rectangles",[room.get("bounds")]):
            x,y=p(b[0],b[1]);svg.append(f'<rect x="{x}" y="{y}" width="{(b[2]-b[0])*60}" height="{(b[3]-b[1])*60}" fill="{colors[room["id"]]}"/>')
    # Planning reservations are dashed, never presented as actual installed assets.
    for item in data["ground_floor"]["reservations"]:
        b=item["bounds"];x,y=p(b[0],b[1]);svg.append(f'<rect x="{x}" y="{y}" width="{(b[2]-b[0])*60}" height="{(b[3]-b[1])*60}" fill="#c7aa6a" fill-opacity=".25" stroke="#ddc28e" stroke-dasharray="5 4"/>')
    for item in data["route_reservations"]:
        b=item["bounds"];x,y=p(b[0],b[1]);svg.append(f'<rect x="{x}" y="{y}" width="{(b[2]-b[0])*60}" height="{(b[3]-b[1])*60}" fill="#8bc5c5" opacity=".12"/>')
    svg += ['<rect x="130" y="245" width="756" height="588" class="wall"/>',
            '<path d="M256 245 V449 M130 449 H217 M295 449 H256" stroke="#78c5cb" stroke-width="5" fill="none" stroke-dasharray="8 5"/>',
            '<path d="M130 575 H470 M548 575 H598 M418 575 V668 M418 746 V833 M598 245 V391 M598 463 V668 M598 746 V833" class="wall"/>',
            '<path d="M469 833 H547 M418 668 V746 M598 668 V746 M470 575 H548" stroke="#bd9b6b" stroke-width="9"/>']
    b=data["ground_floor"]["stair_void"]["bounds"];x,y=p(b[0],b[1])
    svg += [f'<rect x="{x}" y="{y}" width="285" height="66" fill="#152631" stroke="#91a8b5" stroke-width="2"/>',
            f'<path d="M{x+260} {y+33} H{x+25} l15 -8 M{x+25} {y+33} l15 8" stroke="#ecdfbf" fill="none"/>']
    labels=[(-5.25,-3.3,"BATH +","LAUNDRY"),(-2.0,-3.65,"EXISTING STAIR","Keep void + landing"),
            (-2.5,-.5,"BACK HALL","Clear west service route"),(-3.9,2.05,"BEDROOM","Bedside note / reading"),
            (0,2.3,"ENTRY","Coats / boots / turning"),(4.3,-3.3,"KITCHEN","Dining stays in place"),(4.3,2.3,"LIVING","Sofa / wool / hearth")]
    for x,z,top,bottom in labels:
        px,py=p(x,z);svg.append(f'<text x="{px}" y="{py}" text-anchor="middle" font-size="18">{top}</text><text x="{px}" y="{py+25}" text-anchor="middle" class="small">{bottom}</text>')
    svg += ['<text x="970" y="260" font-size="23">BLUEPRINT DECISIONS</text>',
            '<text x="970" y="303" class="small">12.60 Ã— 9.80 m existing upstairs</text>',
            '<text x="970" y="338" class="small">2.10 Ã— 3.40 m bath/laundry reservation</text>',
            '<text x="970" y="373" class="small">New south-facing bathroom door</text>',
            '<text x="970" y="408" class="small">Stove beneath existing chimney</text>',
            '<text x="970" y="443" class="small">North-wall kitchen / clear west lane</text>',
            '<text x="970" y="512" font-size="23">PRESERVE THE FEEL</text>',
            '<text x="970" y="555" class="small">Recorded winter storm and window wind</text>',
            '<text x="970" y="590" class="small">Soft timber-room / hard cellar reverb</text>',
            '<text x="970" y="625" class="small">Local hearth, not global warm ambience</text>',
            '<text x="970" y="695" font-size="23">LEGEND</text>',
            '<text x="970" y="738" class="small">Cream solid lines: existing structure</text>',
            '<text x="970" y="773" class="small">Teal dashed lines: proposed partitions</text>',
            '<text x="970" y="808" class="small">Amber dashed boxes: fixture envelopes</text>',
            '<text x="970" y="843" class="small">Pale teal wash: reserved circulation</text>',
            '<text x="75" y="950" class="small">First batch implemented. Selected fixtures, hinge sweeps, routes and camera spheres checked against the real controller.</text>',
            '<text x="75" y="1000" class="small">GAME ENVIRONMENT STUDY / NOT A CONSTRUCTION DRAWING Â· EXISTING GAMEPLAY GEOMETRY AND AUDIO UNCHANGED</text>','</svg>']
    (DEST/"refined_blueprint.svg").write_text("\n".join(svg),encoding="utf-8")


if __name__=="__main__":main()
