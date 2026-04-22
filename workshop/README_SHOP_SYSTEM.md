# Data-Driven Shop System for Godot 4

A complete, resource-driven shop system with support for multiple currencies, stock management, bulk purchasing, and category filtering.

## File Structure

```
workshop/
├── resources/shop/
│   ├── player_stats.gd          # Autoload for currency/stats management
│   ├── shop_item.gd             # ShopItem resource (item + price + stock)
│   ├── shop_data.gd             # ShopData resource (container for shop inventory)
│   ├── shop_manager.gd          # Optional manager for shop transitions
│   └── example_shop_data.gd     # Example factory functions
└── scenes/ui/shop/
    ├── shop.tscn                # Main shop scene
    ├── shop.gd                  # ShopUI controller script
    ├── shop_item_card.tscn      # Item card scene
    └── shop_item_card.gd        # Item card controller
```

## Setup Instructions

### 1. Register Autoloads

Go to **Project → Project Settings → Autoload** and add:

| Path | Name |
|------|------|
| `res://workshop/resources/shop/player_stats.gd` | `PlayerStats` |

*(Optional)* If using the shop manager:
| Path | Name |
|------|------|
| `res://workshop/resources/shop/shop_manager.gd` | `ShopManager` |

### 2. Update Global.gd Save System

The system automatically integrates with your existing `Global.gd` save system. The modifications have already been added to:
- `get_save_data()` - Includes PlayerStats data
- `load_save_data()` - Restores PlayerStats data

### 3. Node Structure in shop.tscn

```
ShopUI (Control) [shop.gd attached]
├── Background (ColorRect)
└── MarginContainer
    └── VBoxContainer
        ├── HeaderContainer (VBoxContainer)
        │   ├── TitleCurrencyContainer (HBoxContainer)
        │   │   ├── ShopTitle (Label)
        │   │   └── CurrencyLabel (Label)
        │   └── ShopDescription (Label)
        ├── CategoryContainer (HBoxContainer)  [Buttons added dynamically]
        ├── ScrollContainer
        │   └── ItemsGrid (GridContainer)  [Cards instantiated here]
        └── FooterContainer (HBoxContainer)
            ├── RestockButton (Button) [Debug only]
            └── CloseButton (Button)
```

## Creating Shop Data

### Step 1: Create ShopItem Resources

In the FileSystem dock, right-click → **Create New → Resource** → Select `ShopItem`.

Example configuration:
- **Item**: Link to your existing `Item` resource
- **Price**: `100`
- **Currency Type**: `GOLD` (or SILVER, TOKENS)
- **Max Stock**: `-1` (unlimited) or `10` (limited)
- **Current Stock**: Auto-set to max, or customize
- **Category**: `&"weapons"` (StringName)
- **Tags**: `[&"melee", &"rare"]`

### Step 2: Create ShopData Resource

Right-click → **Create New → Resource** → Select `ShopData`.

Configuration:
- **Shop ID**: `&"weapon_shop"` (unique identifier)
- **Shop Name**: `"Weapon Emporium"`
- **Shop Description**: `"Finest weapons in the land!"`
- **Items**: Array of your `ShopItem` resources
- **Categories**: `[&"all", &"weapons", &"armor", &"accessories"]`

## Usage Examples

### Basic Shop Opening (Direct)

```gdscript
# In any script (e.g., NPC interaction, trigger zone)
@export var my_shop_data: ShopData

func _on_shop_trigger_entered(_body):
    var shop_scene = preload("res://workshop/scenes/ui/shop/shop.tscn").instantiate()
    add_child(shop_scene)
    
    var shop_ui = shop_scene as ShopUI
    shop_ui.load_shop(my_shop_data)
    
    # Connect to signals
    shop_ui.item_purchased.connect(_on_item_purchased)
    shop_ui.shop_closed.connect(_on_shop_closed)

func _on_item_purchased(shop_item: ShopItem, quantity: int):
    print("Purchased %d x %s" % [quantity, shop_item.item.item_name])
    # Trigger quests, achievements, etc.

func _on_shop_closed():
    print("Shop closed")
```

### Using ShopManager (Recommended for Multiple Shops)

```gdscript
# In a game manager or player script
@export var weapon_shop: ShopData
@export var potion_shop: ShopData

func _on_npc_talk():
    ShopManager.open_shop(weapon_shop)

func _on_enter_potion_town():
    ShopManager.open_shop(potion_shop)

# Listen to shop events
func _ready():
    ShopManager.shop_opened.connect(func(shop_id): print("Opened shop: ", shop_id))
    ShopManager.shop_closed.connect(func(shop_id): print("Closed shop: ", shop_id))
```

### Hot-Swapping Shop Inventory

```gdscript
# Change shop inventory dynamically (e.g., after quest completion)
func upgrade_shop_inventory():
    var new_shop_data = preload("res://resources/shop/upgraded_shop.tres")
    
    if ShopManager.is_shop_open:
        ShopManager.switch_shop(new_shop_data)
```

### Filtering by Category

```gdscript
# Programmatically filter items
var shop_ui = get_node_or_null("ShopUI")
if shop_ui:
    shop_ui.filter_by_tag(&"weapons")  # Show only weapons
    shop_ui.filter_by_tag(&"all")      # Show all items
```

### Bulk Purchase Configuration

```gdscript
# Enable/disable bulk buying UI
var shop_ui = get_node_or_null("ShopUI")
if shop_ui:
    shop_ui.set_bulk_buy_enabled(true)   # Show quantity spinner
    shop_ui.set_bulk_buy_enabled(false)  # Hide quantity spinner
```

## Features

### 1. Multiple Currencies
- GOLD, SILVER, TOKENS
- Extensible enum for adding more
- Per-item currency type setting

### 2. Stock Management
- Unlimited stock (`max_stock = -1`)
- Limited stock with automatic decrement
- Visual warning when stock ≤ 3
- Restock functionality (via `ShopData.restock_all()`)

### 3. Bulk Purchasing
- Quantity spinner (1-99, auto-capped by stock)
- Single "Buy All" button
- Validates total cost before purchase

### 4. Category Filtering
- Dynamic button generation from `ShopData.categories`
- Toggle-based filtering
- Supports tags for cross-category filtering

### 5. Signal Integration

**ShopUI Signals:**
- `item_purchased(shop_item: ShopItem, quantity: int)`
- `purchase_failed(shop_item: ShopItem, reason: String)`
- `shop_closed()`

**PlayerStats Signals:**
- `currency_changed(new_amount: int)`
- `stat_changed(stat_name: StringName, new_value: Variant)`

**ShopManager Signals:**
- `shop_opened(shop_id: StringName)`
- `shop_closed(shop_id: StringName)`

### 6. Save System Integration

PlayerStats data is automatically saved/loaded via Global.gd:

```gdscript
# Saving (handled automatically)
var save_data = Global.get_save_data()
# Includes: {"player_stats": {"gold": 500, "silver": 0, "tokens": 0, "stats": {...}}}

# Loading (handled automatically)
Global.load_save_data(save_data, scene_data)
```

### 7. Visual Feedback
- Disabled state for unaffordable items (grayed out)
- Disabled state for out-of-stock items
- Red price text when can't afford
- Red stock text when low stock (≤ 3)
- Infinity symbol (∞) for unlimited stock

## API Reference

### PlayerStats (Autoload)

```gdscript
# Get/Set currency
PlayerStats.get_currency(PlayerStats.CurrencyType.GOLD)  # Returns int
PlayerStats.set_currency(1000, PlayerStats.CurrencyType.GOLD)
PlayerStats.add_currency(100, PlayerStats.CurrencyType.GOLD)
PlayerStats.deduct_currency(50, PlayerStats.CurrencyType.GOLD)  # Returns bool
PlayerStats.has_currency(100, PlayerStats.CurrencyType.GOLD)  # Returns bool

# Generic stats
PlayerStats.get_stat(&"player_level")  # Returns Variant
PlayerStats.set_stat(&"reputation", 50)
```

### ShopItem Resource

```gdscript
var item: ShopItem

# Check purchase availability
item.can_purchase()  # bool
item.has_stock()     # bool
item._can_afford()   # bool (internal, checks PlayerStats)

# Purchase
item.purchase()           # bool (single unit)
item.purchase_bulk(5)     # bool (multiple units)

# Stock management
item.get_remaining_stock()  # int (-1 = unlimited)
item.restock()              # Reset to max
```

### ShopData Resource

```gdscript
var shop: ShopData

# Get items
shop.get_items()                    # All items
shop.get_items(&"weapons")          # Filtered
shop.get_sorted_items()             # Sorted by sort_order
shop.get_item_by_resource(item)     # Find by Item resource
shop.has_item(item)                 # Check existence

# Categories & Tags
shop.get_all_tags()  # Array[StringName]

# Stock management
shop.restock_all()   # Restock all items

# Duplication (for independent instances)
var new_shop = shop.duplicate_shop()
```

### ShopUI Controller

```gdscript
var shop_ui: ShopUI

# Load shop
shop_ui.load_shop(shop_data: ShopData)

# Filtering
shop_ui.filter_by_tag(&"weapons")

# Configuration
shop_ui.set_bulk_buy_enabled(true)
shop_ui.enable_bulk_buy = true  # Direct property access

# Refresh
shop_ui.refresh_shop(new_data: ShopData)
shop_ui.close_shop()

# Query
shop_ui.get_shop_id()  # StringName
```

## Troubleshooting

### Issue: Currency not updating
**Solution:** Ensure `PlayerStats` autoload is registered and connected. Check `Engine.has_singleton("PlayerStats")` returns true.

### Issue: Items not appearing
**Solution:** Verify `ShopData.items` array is populated. Check that `ShopItem.item` references valid `Item` resources.

### Issue: Purchase fails silently
**Solution:** Connect to `purchase_failed` signal to see error reasons. Common causes: insufficient funds, out of stock.

### Issue: Save data not persisting
**Solution:** Ensure `Global.get_save_data()` is called before saving and `Global.load_save_data()` after loading. Check that `PlayerStats` autoload exists during save/load.

## Best Practices

1. **Create ShopData as .tres files** - Use the FileSystem dock to create persistent resources
2. **Use categories consistently** - Define categories in ShopData and match them in ShopItem
3. **Duplicate shops for unique instances** - Use `duplicate_shop()` if each shop instance needs independent stock
4. **Handle purchase_failed signals** - Show user-friendly error messages
5. **Test in editor** - ShopItem has `_can_afford()` fallback for editor testing

## Example: Complete Shop Interaction

```gdscript
# shopkeeper.gd
extends NPC

@export var shop_data: ShopData
@export var shop_scene_path: String = "res://workshop/scenes/ui/shop/shop.tscn"

var shop_instance: Control

func _on_interact():
    # Open shop
    shop_instance = load(shop_scene_path).instantiate()
    get_tree().current_scene.add_child(shop_instance)
    
    var shop_ui = shop_instance as ShopUI
    shop_ui.load_shop(shop_data)
    
    # Connect signals
    shop_ui.item_purchased.connect(_on_purchase)
    shop_ui.purchase_failed.connect(_on_purchase_failed)
    shop_ui.shop_closed.connect(_on_shop_closed)
    
    # Pause game (optional)
    get_tree().paused = true

func _on_purchase(shop_item: ShopItem, quantity: int):
    print("Player bought %d x %s" % [quantity, shop_item.item.item_name])
    # Could trigger: give_quest_item(), update_reputation(), etc.

func _on_purchase_failed(shop_item: ShopItem, reason: String):
    # Show toast notification
    var item_name = shop_item.item.item_name if shop_item else "Item"
    show_notification("Cannot buy %s: %s" % [item_name, reason])

func _on_shop_closed():
    get_tree().paused = false
    shop_instance.queue_free()
    shop_instance = null
```

This completes the data-driven shop system implementation!
