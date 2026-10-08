# House refinement: threshold sound and joinery

The next pass connects the existing front door to the weather mix. A local source reuses the recorded breeze loop on the existing Ambience bus. Its level follows the physical hinge angle, so an opening request blocked by the player does not falsely sound wide open. The distant storm retains its existing room/cellar attenuation and Outside-bus filter.

The leak is limited to eight metres, suppressed outside and in the cellar, and attenuated when a wall or closed partition door blocks the listener. It respects the existing ambience/master settings and stops with the other storm voices on scene exit. No synthetic storm replacement or extra global cosy loop is introduced.

The original kitchen cabinets now have inset panels and a recessed visual toe-kick, and the fridge has a door seam. These remain original modules around the detailed imported cooker; they can accept improved models later.

Validation uses the existing domestic/house/note probes plus a targeted sound probe comparing closed, physically open, wall-occluded and cellar listening positions. A subjective listening pass is still needed to judge the balance on the owner's speakers/headphones. The next useful audio asset remains a clean recorded wood-fire loop.

`tools/house_sound_probe.tscn` passes: existing ambience routing, closed-door silence, physically open-door wind, partition attenuation, cellar suppression and no duplicate outside bed. The ray excludes the player so the listener cannot occlude its own wind source. The sound probe frees the live scene before exit to stop streamed loops cleanly.
