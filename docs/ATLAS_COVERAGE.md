# DOS adaptation coverage

This is a coverage ledger, **not a claim that all 150 proposals are implemented**.
The source is the user-supplied `256b_demo.md` (*Beyond the Familiar Shader*).
Only explicit adaptations below count as coverage; existing demos with superficially
similar imagery are not silently credited. No world-first or GPU performance claim is made.

## Scope and constraints

Standalone demos must assemble to at most 256 bytes, use DOS/386/VGA, restore
INT 1Ch on exit, and require no external graphics or music assets. Generated
MPU-401 MIDI requires a General MIDI synth for sound. The MEGA host has no
256-byte limit but individual effects do. New standalone demos do not automatically
become parts of the curated thirteen-part MEGA show.
All 27 implemented atlas demos now have their own [continuous show](ATLAS_SHOW.md).

A GPU-specific mechanism is unavailable natively in this DOS engine: GPU texture
views, sparse residency, interlocks, subgroups, shader clocks, tile/imageblock
storage, VRS, indirect GPU work and driver comparison cannot be represented as
actual GPU experiments here. A separately labelled software analogue may still
be useful. Timing, compiler, race and backend experiments must not be faked with
noise or colour changes. Three-dimensional history, fluids and persistent particle
systems remain unimplemented; this ledger does not assert they are impossible
within 256 bytes, only that no qualifying implementation has been supplied yet.

## Coverage (150 source proposals)

Twenty-eight proposal IDs have explicit adaptations across twenty-seven standalone demos.
The other 122 remain unimplemented, not completed or silently omitted.
The latest batch is described in [temporal fields and topology](DOS_ATLAS_FIELDS.md).

| ID | Source proposal | DOS status |
|---|---|---|
| A01 | History Isosurface | Not implemented |
| A02 | Causal Cone Refraction | Adapted: CAUSAL — squared-distance delay |
| A03 | Time-Gradient Lens | Adapted: TIMELENS — offsets follow a saddle time field's analytical gradient |
| A04 | Temporal Event-Horizon Skin | Adapted: HORIZON — radial time weighting |
| A05 | Chronology Cutaway | Adapted: CAUSAL — quantized chronology shells |
| A06 | Motion-Embossed Matter | Adapted: EMBOSS — spatial gradients of temporal change produce relief shading |
| A07 | Shadow-Echo Manifold | Not implemented |
| A08 | Chronophase Interference | Adapted: PHASE — triangle-wave interference |
| A09 | Spacetime Voronoi | Not implemented |
| A10 | Temporal Topology Surgery | Adapted: SURGERY — a local clock splits and reconnects a union of implicit discs |
| B01 | Order-Dependent Labyrinth | Adapted: COMMUTE — AB/BA shear comparison |
| B02 | Lie-Bracket Camera | Adapted: BRACKET — a sequence of shears and their inverses leaves a residual transform |
| B03 | Path-Memory Material | Not implemented |
| B04 | Holonomy Knots | Not implemented |
| B05 | Non-Abelian Colour Transport | Not implemented |
| B06 | Group-Word Architecture | Not implemented |
| B07 | Curvature-Memory Ribbons | Not implemented |
| B08 | Braid-Space Portals | Not implemented |
| B09 | Projective Monodromy City | Not implemented |
| B10 | Commutator Fracture Field | Not implemented |
| C01 | Sample Constellation Material | Not implemented |
| C02 | Subpixel Coverage Hologram | Not implemented |
| C03 | Coverage-Only Sculpture | Not implemented |
| C04 | Depth Reconstruction Mirage | Not implemented |
| C05 | Stencil-State Organism | Not implemented |
| C06 | Conservative Coverage Bloom | Not implemented |
| C07 | Barycentric Chemistry | Not implemented |
| C08 | Provoking-Vertex Fracture | Not implemented |
| C09 | Sample-Frequency Material Strata | Not implemented |
| C10 | Resolution-Space Sculpture | Adapted: RESFIELD — coordinate quantization, not VRS |
| D01 | Tile-Memory Cellular Skin | Not implemented |
| D02 | Ordered Ink Weave | Not implemented |
| D03 | Imageblock Reaction Sheet | Not implemented |
| D04 | Tile Micro-Fluid | Not implemented |
| D05 | Tile Erosion Architecture | Not implemented |
| D06 | Ephemeral History | Not implemented |
| D07 | PLS Depth-Peeling Organism | Not implemented |
| D08 | Framebuffer-Fetch Palimpsest | Not implemented |
| D09 | Custom Sample-Fusion Mosaic | Not implemented |
| D10 | Explicit Tile-Boundary Metabolism | Not implemented |
| E01 | Residency Silhouette | Not implemented |
| E02 | Virtual-Page Reveal | Not implemented |
| E03 | Page-City | Not implemented |
| E04 | Mip-Residency Topography | Not implemented |
| E05 | Sparse Volumetric Portals | Not implemented |
| E06 | Residency-Age Patina | Not implemented |
| E07 | Format-View Kaleidoscope | Not implemented |
| E08 | Integer/Float Doppelgänger | Not implemented |
| E09 | Layer-Slice Möbius | Not implemented |
| E10 | Device-Address Graph Space | Not implemented |
| F01 | Programmable Blend Loom | Adapted: LOOM — ordered, noncommuting feedback |
| F02 | Order-Sensitive Transparent Calligraphy | Not implemented |
| F03 | Per-Pixel Genealogy | Not implemented |
| F04 | Atomic Histogram Nebula | Not implemented |
| F05 | Atomic Collision Caustics | Not implemented |
| F06 | Compare-Exchange Crystal Nucleation | Not implemented |
| F07 | Atomic Min/Max Terraces | Adapted: TERRACE — serialized extrema reduction |
| F08 | Interlock Overdraw Automaton | Not implemented |
| F09 | Raster-Order Accumulator Clock | Not implemented |
| F10 | Pixel Consensus Machine | Not implemented |
| G01 | Ballot Topology | Adapted: BALLOT — packed predicate neighbourhood |
| G02 | Shuffle Interference | Adapted: SHUFFLE — software permutation, not subgroups |
| G03 | Prefix-Scan Ribbons | Adapted: PREFIX — inclusive software prefix sum |
| G04 | Wave Sort Prism | Adapted: RANK — exact lane-value ranks |
| G05 | Lane-Phase Moiré | Not implemented |
| G06 | Subgroup-Size Beat | Not implemented |
| G07 | Quorum Shading | Not implemented |
| G08 | Wave Permutation Textile | Not implemented |
| G09 | Cross-Lane Cellular Ring | Adapted: RING — periodic cellular neighbours |
| G10 | Divergence Silhouette | Not implemented |
| H01 | Pixel Virtual Machine | Adapted: BYTEVM — bounded eight-opcode interpreter |
| H02 | SPIR-V Word Sculpture | Not implemented |
| H03 | Decoder-Drift Shader Family | Not implemented |
| H04 | Function-Table Material Machine | Not implemented |
| H05 | Branchless Opcode VM | Not implemented |
| H06 | Dual-Use Program Texture | Not implemented |
| H07 | AST Morph Animation | Not implemented |
| H08 | Pipeline-State Opcode Sequencer | Not implemented |
| H09 | Derivative Decoder | Not implemented |
| H10 | Compiler-Variant Sonogram | Not implemented |
| I01 | Reversible Integer Universe | Adapted: REVERSO — exact 16-bit bijection |
| I02 | Lossless Texture Mixer | Adapted: LIFT — reversible byte lifting |
| I03 | Backward Particle Fabric | Not implemented |
| I04 | Cycle-Length Volume | Adapted: ORBIT — exact finite permutation return periods become contour classes |
| I05 | Bijective Cellular Lattice | Not implemented |
| I06 | Permutation-Orbit Cathedral | Not implemented |
| I07 | Reversible Morphology | Not implemented |
| I08 | Involution Mirror World | Adapted: MIRROR — coordinate involution |
| I09 | Orbit-Collision Lens | Not implemented |
| I10 | Reversal-Error Microscope | Not implemented |
| J01 | Bifurcation Foam | Adapted: BIFURC — bounded logistic recurrence |
| J02 | Phase-Change Architecture | Not implemented |
| J03 | Entropy-Gradient Crystal | Not implemented |
| J04 | Predictor-Residual Weather | Adapted: RESIDUAL — analytical prediction error |
| J05 | Consensus Percolation City | Not implemented |
| J06 | Hysteretic Boundary Matter | Adapted: HYSTER — real per-pixel history |
| J07 | Metastable Basin Fireworks | Not implemented |
| J08 | Compressibility Terrain | Adapted: RUNS — run-length description cost |
| J09 | Criticality Fog | Adapted: CRITICAL — nearby initial states are compared after a bounded recurrence |
| J10 | Synchronization Transition Skin | Not implemented |
| K01 | Motion-Only Sculpture | Not implemented |
| K02 | Temporal Colour Object | Not implemented |
| K03 | Reverse-Phi Flowfield | Not implemented |
| K04 | Peripheral Velocity Cathedral | Not implemented |
| K05 | Convex/Concave Metastable Sculpture | Not implemented |
| K06 | Kinetic Occlusion Completion | Not implemented |
| K07 | Binocular Phase Sculpture | Not implemented |
| K08 | Apparent-Motion Lattice | Not implemented |
| K09 | Structure-from-Temporal-Sparsity | Not implemented |
| K10 | Negative-Space Organism | Not implemented |
| L01 | Shader-Clock Topography | Not implemented |
| L02 | Cache-Stride Terrain | Not implemented |
| L03 | Atomic-Contention Aurora | Not implemented |
| L04 | Barrier-Wait Waves | Not implemented |
| L05 | Occupancy Stress Contours | Not implemented |
| L06 | Coalescing Moiré | Not implemented |
| L07 | Divergence-Latency Silhouette | Not implemented |
| L08 | Pipeline-Backpressure Score | Not implemented |
| L09 | Asynchronous-Compilation Mosaic | Not implemented |
| L10 | Sandboxed Unordered-Race Painting | Not implemented |
| M01 | Imageblock State Cube | Not implemented |
| M02 | Raster-Order Ink Layers | Not implemented |
| M03 | Sample-Coverage Glyphs | Not implemented |
| M04 | Memoryless Mandala | Not implemented |
| M05 | Variable-Rate Relief | Not implemented |
| M06 | Pixel-Local Finite-State Screen | Not implemented |
| M07 | Mobile Fetch Palimpsest | Not implemented |
| M08 | Mediump Quantization Glacier | Not implemented |
| M09 | WebGL Transform-Feedback Organism | Not implemented |
| M10 | Backend-Divergence Triptych | Not implemented |
| N01 | Swizzle Automaton | Not implemented |
| N02 | Signedness Doppelgänger | Adapted: SIGNED — signed/unsigned byte interpretation |
| N03 | Mip-Causality Chain | Not implemented |
| N04 | Anisotropy Field Art | Not implemented |
| N05 | Gather-Footprint Calligraphy | Not implemented |
| N06 | Compression-Block Mosaic | Not implemented |
| N07 | MSAA Storage Choir | Not implemented |
| N08 | Depth/Stencil Dual Narrative | Not implemented |
| N09 | Cubemap Monodromy | Not implemented |
| N10 | Bindless Resource Constellation | Not implemented |
| O01 | Indirect-Draw Ecosystem | Not implemented |
| O02 | Geometry Genealogy | Not implemented |
| O03 | Self-Sizing Dispatch | Not implemented |
| O04 | GPU Command-Graph Organism | Not implemented |
| O05 | Occlusion-Query Choreography | Not implemented |
| O06 | Visibility-Driven Evolution | Not implemented |
| O07 | Render-to-Argument Feedback | Not implemented |
| O08 | Recursive Draw Grammar | Not implemented |
| O09 | Self-Organizing LOD Civilization | Not implemented |
| O10 | Pipeline-Statistics Creature | Not implemented |

See [implementation notes](DOS_ATLAS.md) for the six additional demos and
[temporal notes](TEMPORAL_ATLAS.md) for CAUSAL and PHASE. Formula tests exercise
clock boundaries and byte arithmetic, but are not real-hardware timing measurements.
