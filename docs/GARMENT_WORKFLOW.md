# Garment strategy

The Wayfarer, Nocturne and Trailwarden prototypes were discarded. Procedural torso rings, separate overlapping sleeves, nearest-vertex weights and shader panels did not produce acceptable fitted clothing on this model. They are removed from the creator and its generator.

The original costume remains the supported outfit. Hair, eye/cloth/trim colour, saved designs and animation preview remain available. Older saved outfit IDs fall back to the original costume in memory; the files keep their names and colours.

## Authoring foundation

Open `assets/characters/authoring/garment_workbench.blend` in Blender. It contains an untouched hidden vendor reference and a working copy with separate skin, original costume and hair meshes. Bone names, rest transforms, UVs and weights are preserved. `body_audit.json` lists geometric boundary candidates below the neck after accounting for duplicated UV/normal seam vertices.

The working skin is explicitly marked incomplete. The file is an inspected starting point, not a completed body reconstruction or a new outfit. It is excluded from Godot import. Rebuild it with:

```powershell
blender --background --factory-startup --python-exit-code 1 --python tools/prepare_garment_workbench.py
```

## Build one fitted garment first

1. Inspect the source from front, side, rear and underneath. Use boundary candidates to identify absent surfaces, then confirm them visually; an open mouth or material seam is not an abdomen gap.
2. Complete the necessary body surfaces by joining the real boundary loops and shaping anatomical contours against the existing torso and pelvis. Use deformation loops and clean vertex normals. Keep a separate continuous body for fitting; preserve its skeleton/rest pose and vendor provenance.
3. Tailor one restrained fitted garment from that completed surface. Establish connected torso, shoulder, armhole, sleeve and hip topology. Use a small controlled clearance, with intentional seams, cuffs and thickness. Retain covered body geometry in the authoring source; hide only reviewed regions in the runtime output.
4. Transfer weights by reviewed surface interpolation and paint corrections around shoulders, elbows, hips and knees. Normalize the chosen deform influences. A nearest-vertex assignment alone is not final skinning.
5. Inspect the garment at rest and in the actual elf's idle, walk, jog, sprint, backward walk, crouch, jump and landing poses. Review contact points and silhouettes from several angles. Fix intersections, detached seams and deformed panels in geometry/weights before texturing.
6. Unwrap the finished garment consistently, texture the intended fabric and finish, and round-trip the staged export through Blender and Godot. Do not use shading to conceal broken topology.
7. Add the garment to the creator only after its fit and deformation are visually sound. Derive further designs from that validated construction rather than generating three disconnected shells in advance.

CLI automation remains useful for inspection, versioned export, weight/UV reports and repeatable pose captures. Topology, fit and deformation quality determine readiness; a successful import or control probe cannot establish those qualities.
