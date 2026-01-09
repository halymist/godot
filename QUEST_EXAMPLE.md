# Quest System - Persistent Options Example

## Overview
The quest system has been updated to support **persistent dialogue options** instead of the old slide-based navigation.

## Key Changes

### 1. Renamed Classes
- `QuestSlide` → `QuestState`
- `slide_target` → `navigates_to_slide`

### 2. New Fields

#### QuestState (formerly QuestSlide)
```gdscript
@export var initially_visible_options: Array[int] = []  # Which options are visible when entering this state
```

#### QuestOption
```gdscript
@export_multiline var response_text: String = ""  # Text shown when option is clicked
@export var shows_option_ids: Array[int] = []     # Show these options after clicking
@export var hides_option_ids: Array[int] = []     # Hide these options after clicking
@export var is_blocking: bool = false             # If true, hides ALL other options
@export var navigates_to_slide: int = 0           # 0 = stay, >0 = go to state, -1 = end quest
```

### 3. Behavior
- **Clicked options are always hidden** (exhausted)
- Options can show/hide other options dynamically
- Text is **replaced**, not appended
- Options persist until explicitly hidden or navigation occurs
- "Blocking" actions (attack, leave) can hide all other options

## Example Quest Structure

### State 1: Meeting the Merchant
```
Text: "A merchant stands before you with a friendly smile."

Options:
  [1] "What do you sell?" (option_index: 1)
      - response_text: "The merchant shows you his wares: rare herbs and potions."
      - shows_option_ids: [2, 3]  # Show buy/special options
      - navigates_to_slide: 0  # Stay on current state
  
  [4] "Tell me about yourself" (option_index: 4)
      - response_text: "I've been traveling these lands for 20 years..."
      - shows_option_ids: [5]  # Show follow-up question
      - navigates_to_slide: 0
  
  [6] "Goodbye" (option_index: 6)
      - is_blocking: true  # Hides all other options
      - navigates_to_slide: -1  # End quest

initially_visible_options: [1, 4, 6]  # Only these 3 visible at start
```

After clicking "What do you sell?" (option 1):
- Option 1 is hidden (clicked)
- Text updates to response_text
- Options 2 and 3 appear (buy options)
- Options 4 and 6 still visible (not affected)

### State 2: Combat Result
```
Text: "You defeated the bandit!"

Options:
  [1] "Loot the body" (option_index: 1)
      - response_text: "You find 50 silver and a rusty sword."
      - navigates_to_slide: 3  # Go to next state
  
  [2] "Leave quickly" (option_index: 2)
      - navigates_to_slide: 3

initially_visible_options: [1, 2]  # Both visible immediately
```

## Migration Notes

### Old System (Slide-based)
```
State 1: "Hello traveler"
  Option: "Ask about quest" → Go to State 2
  Option: "Leave" → End quest

State 2: "I need help with bandits"
  Option: "Accept" → Go to State 3
  Option: "Decline" → End quest
```

### New System (Persistent Options)
```
State 1: "Hello traveler"
  initially_visible_options: [1, 2]
  
  Option 1: "What brings you here?"
    response_text: "I'm troubled by bandits..."
    shows_option_ids: [3]  # Show "I'll help" option
    navigates_to_slide: 0  # Stay
  
  Option 2: "Tell me about yourself"
    response_text: "I've lived here all my life..."
    navigates_to_slide: 0
  
  Option 3: "I'll help with the bandits"
    is_blocking: true
    navigates_to_slide: 2  # Go to combat state
  
  Option 4: "Goodbye"
    navigates_to_slide: -1  # End quest
```

## Benefits
- More natural conversations (can ask multiple questions)
- Options can appear/disappear dynamically
- Supports "exploration" dialogue before committing to action
- "Blocking" actions (combat, leave) clearly end the conversation
- Easier to create branching dialogue trees

## Technical Implementation
- `visible_option_ids: Array[int]` tracks currently visible options
- When an option is clicked:
  1. Check requirements/deduct costs
  2. Replace text with `response_text` (if provided)
  3. Remove clicked option from `visible_option_ids`
  4. Add `shows_option_ids` to `visible_option_ids`
  5. Remove `hides_option_ids` from `visible_option_ids`
  6. If `is_blocking`, clear all `visible_option_ids`
  7. If `navigates_to_slide != 0`, load new state or end quest
  8. Else, refresh display with updated options
