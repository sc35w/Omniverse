# Omniverse / Isaac Sim Learning Roadmap

Goal: robotics simulation via NVIDIA Isaac Sim (built on Omniverse Kit + OpenUSD).
Background: robotics/ML, comfortable with sim & RL concepts already.
Constraint: no local RTX GPU — cloud GPU required.

## 0. The landscape (so the pieces make sense)

- **OpenUSD** — the scene-description format everything sits on (like a "git for 3D
  scenes" — layers, composition, references). You don't need to master it, but
  understand stages/layers/prims before touching Isaac Sim.
- **Omniverse Kit** — the app framework (extensions, Python/C++ APIs) that Isaac Sim,
  USD Composer, etc. are all built on top of.
- **Isaac Sim** — the robotics simulation app: PhysX physics, RTX rendering, sensor
  simulation (cameras, LiDAR, IMU), ROS/ROS2 bridge, synthetic data generation
  (Replicator).
- **Isaac Lab** — sits on top of Isaac Sim; this is where you do RL / imitation
  learning training (successor to Isaac Gym / Orbit). This is likely your real
  destination given your ML background.

Rough mental model: **USD = data format → Kit = app framework → Isaac Sim = robotics
app → Isaac Lab = learning framework on top of Isaac Sim.**

## 1. Hardware/cloud setup (do this first — it's the actual blocker)

Isaac Sim needs an **RTX-capable** GPU (has RT cores) — plain compute GPUs like A100
don't work well for the renderer. Options with RT cores:

- **NVIDIA Brev.dev** — easiest on-ramp, has Isaac Sim launchables/templates,
  pay-as-you-go GPU instances (L4/L40/A10G-class). Good starting point.
- **AWS** — G5 (A10G) or G6 (L4) instances.
- **Azure** — NV-series (A10-based).
- **GCP** — G2 instances (L4).
- **Lambda / CoreWeave** — check current RTX-class GPU availability.

Isaac Sim runs headless on the cloud box and you either:
- stream the GUI to your laptop via WebRTC (Omniverse Streaming Client / browser), or
- run fully headless and just look at rendered output / logs (common for RL training
  once you're past the exploration phase).

**Action:** spin up one cheap instance (e.g. Brev.dev Isaac Sim template) just to
confirm streaming works before investing in tutorials.

## 2. USD fundamentals (~1–2 days)

- NVIDIA's "Learn USD" / OpenUSD docs — stages, prims, layers, composition arcs,
  references vs payloads.
- Don't go deep — just enough to read/write simple USD scenes and understand what
  Isaac Sim is doing under the hood when it loads a robot.

## 3. Isaac Sim core (~1 week)

- Install/launch Isaac Sim on your cloud instance, connect via streaming client.
- Work through NVIDIA's official Isaac Sim tutorials in order:
  1. UI navigation, adding objects, basic physics
  2. Importing a robot (URDF import — use a robot you know, e.g. a simple arm or
     a mobile base)
  3. Articulations & joint control via Python API (`isaacsim.core` / standalone
     Python scripts — this is where your Python background pays off immediately)
  4. Sensors: camera, LiDAR, contact sensors
  5. ROS2 bridge (if you use ROS2 — publish/subscribe between Isaac Sim and ROS2
     nodes)
- Prefer the **standalone Python workflow** over GUI-only clicking — scriptable sims
  are what you'll actually use for RL later.

## 4. Synthetic data generation (optional branch, ~2-3 days)

- Isaac Sim **Replicator** — domain randomization, synthetic dataset generation for
  perception training. Skip this initially if RL/control is your real target; revisit
  if you need vision-based policies.

## 5. Isaac Lab — RL training (~1-2 weeks, the main event)

- Isaac Lab docs: environment structure (`gym`-like API), manager-based vs
  direct-workflow envs.
- Run an existing example task (e.g. a locomotion or manipulation task) end-to-end
  first — don't write a custom env yet, just get training loop + Isaac Sim rendering
  working together on your cloud GPU.
- Then: swap in your own robot (URDF/USD import) and a custom task.
- Leverage your RL background here — the new surface area is mainly "how Isaac Lab
  wraps Isaac Sim as a vectorized simulation backend," not RL itself.

## 6. Project-based consolidation

Pick one concrete project to force integration of everything above, e.g.:
- Import a specific robot → set up a manipulation or navigation task in Isaac Lab →
  train a policy → validate in Isaac Sim with domain-randomized synthetic sensors.

## Resources

- Omniverse docs: docs.omniverse.nvidia.com
- Isaac Sim docs: docs.isaacsim.omniverse.nvidia.com
- Isaac Lab docs: isaac-sim.github.io/IsaacLab
- NVIDIA DLI (Deep Learning Institute) — has structured Isaac Sim/Omniverse courses
  with guided labs (courses.nvidia.com) — worth it if you prefer structured courses
  over self-directed docs.
- NVIDIA Isaac GitHub orgs — sample repos, reference robots/tasks.
- Brev.dev — cloud GPU + Isaac Sim launch templates.

## Notes / log

(Use this section to track what you've tried, blockers, cloud instance costs, etc.)
