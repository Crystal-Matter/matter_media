# matter media

Windows media control bindings (play/pause, next/previous, volume) plus a simple tray app UI that is controlled on your phone via Matter protocol.

## limitations

Apple currently has [limited matter support](https://support.apple.com/en-au/102135#before-you-begin) in the Home app.

> The Home app currently supports these types of Matter accessory: air conditioners, bridges, lights, locks, sockets, switches, thermostats, blinds and shades, and sensors (motion, ambient light, contact, temperature and humidity).

So we mapping these controls to:

* EP1: OnOff Switch = Play/Pause (stateful)
* EP2: Dimmable Light = Volume (LevelControl)
* EP3: OnOff Switch = Next (momentary)
* EP4: OnOff Switch = Previous (momentary)

We'll migrate to something like this once support is added:

* Endpoint 1: Basic Video Player = Media Controls
* Endpoint 2: Speaker = Volume

## Usage (Windows)

- Build: `shards build --release`
- Run: `./bin/matter_media`

Tray menu supports: Play/Pause, Next, Previous, Stop, Volume Up/Down, Mute.

## Contributing

1. Fork it (<https://github.com/spider-gazelle/matter_media/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stephen von Takach](https://github.com/stakach) - creator and maintainer
