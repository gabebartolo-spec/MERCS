extends Node
## EventBus autoload: will carry typed event records (BattleEvent, WorldEvent,
## StoryEvent) to presentation, and nothing else (05_STYLE_CODE.md). Sim never references
## it: sim entry points return typed event lists, or sim objects expose their own
## signals, and presentation relays them here (D-021). Empty in Phase 0.
