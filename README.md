# ox_target (RedM / RSG-Core)

A third-eye targeting system for RedM. Hold a key, look at a ped, horse, wagon, object or zone, and pick an option from a menu.

This is a fork of [overextended/ox_target](https://github.com/overextended/ox_target) 1.18.1. It has been ported from GTA V to RedM (`rdr3`), and its group and item checks use RSG-Core. The export API matches upstream, so scripts written for ox_target work without changes.

---

## Features

- **Targets everything:** peds, players, horses, wagons, objects, specific models, specific entities, and box, sphere or poly zones.
- **RSG-Core integration:** show options only to certain jobs or gangs (with an optional minimum grade), or only to players carrying certain items.
- **Nested menus:** options can open submenus, and a **Go back** option is added for you.
- **Bone and offset targeting:** attach an option to one part of a model, such as a wagon wheel or a crate lid.
- **Custom visibility:** use `canInteract` to decide when an option shows. Errors inside it are caught, so they can't break the menu.
- **Five action types:** an option can run a client event, server event, command, export or callback.
- **RedM-native controls:** hold or toggle a configurable key, and click options with the left or right mouse button.
- **Zone markers:** nearby zones show a small marker that turns white when you aim at the zone.
- **RDR2 leather & gold UI:** a dark menu with round icon badges and uppercase labels, using Font Awesome 6 icons.
- **qtarget compatibility:** provides `qtarget`, so older scripts that use qtarget exports keep working.
- **Automatic cleanup:** when a resource stops, its options and zones are removed. Entities that have been deleted are cleared from every client.
- **Translations:** 20+ locales, loaded with ox_lib.

---

## Requirements

| Resource | Version |
|---|---|
| [ox_lib](https://github.com/overextended/ox_lib) | 3.30.0 or newer |
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | optional; needed for `groups` and `items` checks |

---

## Installation

1. Place the `ox_target` folder in your resources directory, for example `resources/[standalone]/ox_target`.
2. Make sure it starts **after `ox_lib`** and **before** any resource that uses it. If rsg-core is running, start it after rsg-core as well.

   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure ox_target
   ```

3. Remove or disable any other targeting resource (`rsg-target`, `qtarget`, `qb-target`). This one provides `qtarget` itself.
4. Optionally add any of the convars below to `server.cfg`, then restart the server.

---

## Configuration

All settings are convars. Use `setr` so clients can read them.

```cfg
setr ox_target:openKey 0x8AAA0AD4   # control hash that opens targeting (Left Alt)
setr ox_target:toggleHotkey 0       # 1 = press to open/close, 0 = hold to keep open
setr ox_target:leftClick 1          # 1 = left click selects, 0 = right click
setr ox_target:drawSprite 24        # max zone markers drawn per frame, 0 disables them
setr ox_target:debug 0              # 1 = debug options and /ox_target_debugzones
```

| Convar | Default | Description |
|---|---|---|
| `ox_target:openKey` | `0x8AAA0AD4` | RedM control hash for the targeting key. The default is `INPUT_PC_FREE_LOOK` (Left Alt). |
| `ox_target:toggleHotkey` | `0` | `0`: hold the key to target, and releasing it closes the menu. `1`: press once to open and again to close. |
| `ox_target:leftClick` | `1` | Mouse button that focuses the menu so you can click an option. Right-click (aim) always closes the menu. |
| `ox_target:drawSprite` | `24` | Maximum number of nearby zone markers drawn. Set to `0` to hide them. |
| `ox_target:debug` | `0` | Adds debug options to every ped, wagon, object and the world, plus a debug crosshair marker. |

**Language:** ox_lib picks the locale. Set it with `setr ox:locale en` (or `de`, `fr`, and so on). Locale files are in `locales/`.

---

## How players use it

1. **Hold Left Alt.** An eye icon appears in the centre of the screen.
2. **Look at something.** The eye lights up when there are options, and they appear to the right of the eye.
3. **Left-click** (keep holding Alt) to get a cursor, then **click an option**.
4. **Right-click** or **release Alt** to close.

---

## How developers use it

Call the exports from any client script:

```lua
local ox_target = exports.ox_target
```

### Option fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique ID per resource. It is used to remove or replace the option. |
| `label` | string | Text shown in the menu. |
| `icon` | string | Font Awesome class, e.g. `'fa-solid fa-horse'`. |
| `iconColor` | string | CSS colour for the icon. |
| `distance` | number | Maximum interaction distance (default `7`). |
| `groups` | string \| string[] \| table | RSG job/gang filter: `'sheriff'`, `{ 'sheriff', 'marshal' }`, or `{ sheriff = 2 }` for a minimum grade. |
| `items` | string \| string[] \| table | Required items: `'lockpick'`, `{ 'rope', 'knife' }`, or `{ rope = 2 }` for minimum amounts. |
| `anyItem` | boolean | If true, the player needs only one of the `items`. |
| `bones` | string \| string[] | Show only when aiming near these bones. |
| `offset` | vector3 | Show only when aiming near this point on the model (relative 0–1, or absolute with `absoluteOffset = true`). |
| `offsetSize` | number | Radius around the offset point (default `1`). |
| `canInteract` | function | `function(entity, distance, coords, name, bone) return true end` |
| `menuName` | string | Puts this option inside a submenu. |
| `openMenu` | string | Opens the submenu with this name when clicked. |

Give each option **one** action:

| Field | Runs |
|---|---|
| `onSelect` | `function(data) end` |
| `event` | `TriggerEvent(event, data)` |
| `serverEvent` | `TriggerServerEvent(serverEvent, data)`, where `data.entity` is a **network ID** |
| `command` | `ExecuteCommand(command)` |
| `export` | `exports[resource][export](nil, data)` |

`data` holds the option's own fields plus `entity`, `coords`, `distance` and `zone`.

### Global targets

```lua
ox_target:addGlobalPed({
    {
        name = 'myres:talk',
        icon = 'fa-solid fa-comments',
        label = 'Talk',
        distance = 2.0,
        onSelect = function(data)
            print('Talking to ped', data.entity)
        end
    }
})

ox_target:addGlobalPlayer({ ... })
ox_target:addGlobalVehicle({ ... })   -- wagons, carts, boats
ox_target:addGlobalObject({ ... })
ox_target:addGlobalOption({ ... })    -- always shown, whatever you are looking at

ox_target:removeGlobalPed('myres:talk')   -- same pattern for the others
```

### Models

```lua
ox_target:addModel({ `p_chair05x`, `p_chair_crate02x` }, {
    {
        name = 'myres:sit',
        icon = 'fa-solid fa-chair',
        label = 'Sit down',
        distance = 1.5,
        event = 'myres:client:sit'
    }
})

ox_target:removeModel(`p_chair05x`, 'myres:sit')
```

### Entities

```lua
-- networked entity (shared across clients) - pass a network ID
ox_target:addEntity(NetworkGetNetworkIdFromEntity(wagon), { ... })
ox_target:removeEntity(netId, 'myres:option')

-- local entity (e.g. a client-spawned shop NPC) - pass the entity handle
ox_target:addLocalEntity(ped, {
    {
        name = 'myres:shop',
        icon = 'fa-solid fa-store',
        label = 'Open General Store',
        serverEvent = 'myres:server:openShop'
    }
})
ox_target:removeLocalEntity(ped)
```

### Zones

```lua
local id = ox_target:addBoxZone({
    name = 'valentine_sheriff_desk',
    coords = vec3(-275.5, 805.0, 119.4),
    size = vec3(1.5, 1.0, 1.5),
    rotation = 10,
    debug = false,
    drawSprite = true,
    options = {
        {
            name = 'sheriff:duty',
            icon = 'fa-solid fa-star',
            label = 'Toggle duty',
            groups = 'vallaw',
            serverEvent = 'myres:server:toggleDuty'
        }
    }
})

ox_target:addSphereZone({ coords = vec3(...), radius = 1.0, options = { ... } })
ox_target:addPolyZone({ points = { vec3(...), vec3(...), vec3(...) }, thickness = 3, options = { ... } })

ox_target:zoneExists('valentine_sheriff_desk') -- true / false
ox_target:removeZone(id)                      -- by id or by name
```

### Submenus

```lua
ox_target:addGlobalPed({
    { name = 'myres:interact', icon = 'fa-solid fa-hand', label = 'Interact', openMenu = 'interact' },
    { name = 'myres:greet', icon = 'fa-solid fa-hat-cowboy', label = 'Tip hat', menuName = 'interact', event = 'myres:greet' },
    { name = 'myres:rob', icon = 'fa-solid fa-gun', label = 'Rob', menuName = 'interact', event = 'myres:rob' },
})
```

### Job, gang and item restrictions

```lua
ox_target:addGlobalPlayer({
    {
        name = 'law:cuff',
        icon = 'fa-solid fa-handcuffs',
        label = 'Cuff',
        groups = { vallaw = 0, rholaw = 0 }, -- any grade of either job
        items = 'handcuffs',
        serverEvent = 'law:server:cuff'
    }
})
```

### Other exports

```lua
ox_target:disableTargeting(true)  -- block targeting, e.g. during a cutscene or while dead
ox_target:disableTargeting(false)
ox_target:isActive()              -- true while the eye is open
```

### Server-side validation (important)

`groups`, `items`, `distance` and `canInteract` only **hide options on the client**. A cheater can trigger your server event directly, so every `serverEvent` handler must repeat its own checks:

```lua
RegisterNetEvent('law:server:cuff', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= 'vallaw' then return end

    local target = NetworkGetEntityFromNetworkId(tonumber(data?.entity) or 0)
    if target == 0 or #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(target)) > 3.0 then return end

    if not exports['rsg-inventory']:HasItem(src, 'handcuffs', 1) then return end
    -- ...
end)
```

---

## qtarget compatibility

`ox_target` provides `qtarget`, so these old exports are translated automatically: `AddBoxZone`, `AddPolyZone`, `AddCircleZone`, `RemoveZone`, `AddTargetBone`, `AddTargetEntity`, `RemoveTargetEntity`, `AddTargetModel`, `RemoveTargetModel`, `Ped`, `Vehicle`, `Object`, `Player` (and their `Remove*` versions).

---

## Debugging

Set `setr ox_target:debug 1` and restart. Then:

- Every ped, wagon and object gets a **(Debug)** option. Selecting it prints the entity, model and coords to the F8 console.
- A red marker shows where the crosshair raycast lands.
- Run `/ox_target_debugzones` to create a test box zone and a test sphere zone next to you.

---

## Credits & licence

Original resource by [Overextended](https://github.com/overextended/ox_target). RedM / RSG-Core port maintained for this server. Released under the MIT licence (see `LICENSE`).
