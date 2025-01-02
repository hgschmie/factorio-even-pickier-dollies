# Even Pickier Dollies

This is a rewrite of the [Picker Dollies](https://github.com/Nexela/PickerDollies) mod by @nexela which has been modified to work with Factorio 2.0. Nexela did awesome work with this for Factorio 1.1. I will claim responsibility for all the bugs that this mod shows with Factorio 2.0.

Starting with release 2.4.0, entities are no longer teleported into "safe positions" first. This makes a lot of the problems with 2.0 go away (and will make EPD much more usable in very tight spots or crowded situations such as space platforms).

Starting with release 2.5.0, "transporter mode" can be enabled in the startup settings which allows certain entities (currently only belts and 1x1 loaders) to be moved even though these entities can not be teleported. This is done by creating a clone of the entity at the new position and destroying the original entity. This may cause problems in some scenarios or with some mods, so when in doubt, leave the startup setting off.

Hover over entities and use the keybindings to move entities around. Entities will keep their wire connections and settings. This allows you to build your set up spaced out and when you are finished push it all together for a nice tight build. Some entities can't be shoved around. Also respects max wire distance.

Note: Moving some modded entities that rely on position can cause issues. There is an API available that mod authors can use to be notified of these events.

The [EPD API is documented here](https://github.com/hgschmie/factorio-even-pickier-dollies/blob/main/API.md).

[![Even Pickier Dollies in Action](https://raw.githubusercontent.com/hgschmie/factorio-even-pickier-dollies/refs/heads/main/.portal/even-pickier-dollies.gif)]
