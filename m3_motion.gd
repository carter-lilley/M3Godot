class_name M3Motion
extends RefCounted

## Shared motion constants for M3 component animations.
## Constants only — no autoload, no manager. Values follow M3 motion guidance
## tuned to match the app's existing feel (card focus pop, sheet slides).

# Durations (seconds)
const STATE: float = 0.15        ## State fades, presses, hover layers
const OVERLAY: float = 0.2       ## Dialogs, menus, snackbars, tooltips
const EMPHASIZED: float = 0.25   ## Morphs: switch thumb, nav pill
const ITEM_STAGGER: float = 0.015 ## Menu item cascade delay

# Easing tokens
const EASE_ENTER_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC
const EASE_ENTER: Tween.EaseType = Tween.EASE_OUT
const EASE_EXIT_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC
const EASE_EXIT: Tween.EaseType = Tween.EASE_IN
const EASE_POP_TRANS: Tween.TransitionType = Tween.TRANS_BACK
const EASE_POP: Tween.EaseType = Tween.EASE_OUT
const EASE_FADE_TRANS: Tween.TransitionType = Tween.TRANS_QUAD
const EASE_FADE: Tween.EaseType = Tween.EASE_OUT
