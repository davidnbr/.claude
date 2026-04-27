---
description: Starts a new feature track. Creates spec.md and plan.md.
argument-hint: [track-name]
---

# Context
The user wants to start a new unit of work called "".
You must follow the "Conductor" strict protocol: **Context -> Spec -> Plan -> Implement**.

# Goal
1. Create a directory `conductor/tracks//`.
2. Inside that directory, create two files:
   - `spec.md`: A detailed requirements document. Ask the user for the "User Story" and "Acceptance Criteria" to fill this.
   - `plan.md`: A step-by-step implementation plan.

# Execution
1. Create the folder and files.
2. Interview the user to fill out `spec.md` first.
3. Once `spec.md` is agreed upon, generate the step-by-step tasks in `plan.md`.
4. DO NOT write any code yet. Stop after the plan is created.
