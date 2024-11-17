# Even Pickier Dollies

This is a fork of the [Picker Dollies](https://github.com/Nexela/PickerDollies) mod by @nexela which has been modified to work with Factorio 2.0. Nexela did awesome work with this for Factorio 1.1. I will claim responsibility for all the bugs that this mod shows with Factorio 2.0.

## How it works (and a few 2.0 problems)

Even Pickier Dollies (EPD) (and the original "Picker Dollies") move entities around by doing a two step process:

- find a "safe position" for the entity. This is usually a few tiles away. There are up to five attempts to find such a "safe position", each in increasingly more distance. Once a safe position is found, teleport the entity there.
- check if the entity fits in the "next" position (left, right, up, down or rotate). To be able to do so, it had to be teleported away first. If it fits, teleport it into the new spot.

Why is it done this way? Can't we just "teleport" the original unit around?

Yes, we absolutely could. But now any entity could be happily moved over other enties, into water and in any place where they should not be able to be placed. Teleport does not care *where* it places an entity.

There is a `can_place_entity` method that can be used to avoid this. It works great and provides all the checks needed. But when checking the target position it will take all entities into account. And if the target position overlaps with the current position of an entity (which it does for any entity wider than a single tile), then the check will flag "can not place" because the entity would theoretically collide with itself. And how to avoid this? The entity needs to be moved away...  😁

All of this worked great in 1.1 (well, there were actually a few problems with that, especially when the "safe position" overlapped with some other entity, but that did not matter in 1.1).

Now, enter 2.0.

- When moving a "pipe to ground" and the "safe position" overlaps with another pipe, that pipe gets disconnected. This is the bug that was reported in the mod forums. It seems to be a consequence of the new fluid system (a pipe disconnect will happen exactly 20 tiles to the right when moving e.g. a pipe to the ground connected to a pipeline).
- When moving an entity that contains fluid into a "safe position" that happens to be adjacent to another entity that it can connect to (e.g. a storage tank next to a pipe), the fluid out of the storage tank will "spill" into the pipe, even though it will just be teleported there and away again.

Both of those things are either annoying (the first) or really bad (the second).

First thought: Create a surface just for EPD, teleport the entity onto the same spot on that other surface (which is obviously empty), then teleport from there to the new location. Unfortunately, the docs state "Only players, cars, and spidertrons can be teleported cross-surface."

### Finding a "safe position"

Whenever an entity is moved, a safe position is calculated as follows:

- choose a direction. Picker Dollies used straight "east" for this. EPD uses "southeast" (which translates to "6"). This can be controlled as a startup setting ("Direction to check for safe positions when moving entities"). This value should never need changing as any direction should be as good as any other. At the very least, do not choose any "straight" directions as this really interferes e.g. with long pipelines.
- choose a "step distance". This is 20 tiles (and controlled by "Spacing increase for safe positions when moving entities", another startup setting). This value can be increased or decreased a bit if necessary.

In a number of attempts (up to five), the mod calculates a "safe" position where it can move the entity to. The first one that works is taken.

For almost all entities, that is it. However, for entities that contain fluid, an additional check to ensure that there is at least one tile separation between the entity to teleport and adjacent entities in the "safe position".

### I got the "Can not move &lt;my entity&gt;, no safe position found!" message

First turn on debugging. There is a runtime setting for it. In debug mode, epd will show the position it wants to move an entity to (blue square) and the safe positions it evaluated (red and green squares). The error message above appears if no green square could be found.

Depending on your factory, it may be necessary to modify the direction or spacing. If the problem is specific to fluid containing entities (pipes, storage tanks etc), you can turn off the 'Move fluid related entities extra carefully' settings which loosens up EPDs ability to move these entities. However, if the "green square", that is used as a safe position, is next to another entity that this might connect to, it is possible to create "fluid contamination" which needs to be cleaned up afterwards.

If the problem persists, please take a screenshot with debug enabled showing the various squares and add it as an issue to github or post to the mod discussion forum.

----

## (original README)

Hover over entities and use the keybindings to move entities around. Entities will keep their wire connections and settings. This allows you to build your set up spaced out and when you are finished push it all together for a nice tight build. Some entities can't be shoved around. Also respects max wire distance.

Note: Moving some modded entities that rely on position can cause issues. There is an API available that mod authors can use to be notified of these events.

[![Even Pickier Dollies in Action](https://github.com/hgschmie/factorio-even-pickier-dollies/blob/main/.portal/even-pickier-dollies.gif)]

## Remote API

This module retains the 'PickerDollies' API name to be compatible with all the other things out there that interface with it.

Whenever a player moves an entity using picker dollies, an event is
raised. Listening for this event will allow you to update your
entities if needed.

In your mods on_load and on_init events add:

```lua
if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), your_function_to_update_the_entity)
end
```

The dolly moved event returns a table with the following the information:
```lua
{
    player_index = player_index, -- The index of the player who moved the entity
    moved_entity = entity,       -- The entity that was moved
    start_pos = position         -- The position that the entity was moved from
}
```

In addition a remote api to disallow moving of an entity is available:
```lua
if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["add_blacklist_name"] then
    remote.call("PickerDollies", "add_blacklist_name", "name-of-your-entity")
end
```
