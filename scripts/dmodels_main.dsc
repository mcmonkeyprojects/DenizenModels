# +---------------------------
# |
# | D e n i z en   M o d e l s
# | AKA DModels - dynamically animated models in minecraft
# |
# +---------------------------
#
# @author mcmonkey
# @contributors Max^
# @date 2022/06/01
# @updated 2022/07/06
# @denizen-build REL-1772
# @script-version 1.4
#
# This takes BlockBench "BBModel" files, converts them to a client-ready resource pack and Denizen internal data,
# then is able to display them in minecraft and even animate them, by spawning and moving invisible armor stands with resource pack items on their heads.
#
# Installation:
# 1: Copy the "scripts/dmodels" folder to your "plugins/Denizen/scripts" and "/ex reload"
# 3: Note that you must know the basics of operating resource packs - the pack content will be generated for you, but you must know how to install a pack on your client and/or distribute it to players as appropriate
# 4: Take a look at the config settings in the bottom of this file in case you want to change any of them.
#
# Usage:
# 1: Create a model using blockbench - https://www.blockbench.net/
# 1.1 Create as a 'Generic Model'
# 1.2 Make basically anything you want
# 1.3 Note that there is a scale limit, of roughly 73 blockbench units (about 4 minecraft block-widths),
#     meaning you cannot have a section of block more than 36 blockbench units from its pivot point.
#     If you need a larger object, add more Outliner groups with pivots moved over.
# 1.4 Make sure pivot points are as correct as possible to minimize glitchiness from animations
#     (for example, if you have a bone pivot point in the center of a block, but the block's own pivot point is left at default 0,0,0, this can lead to the armor stand having to move and rotate at the same time, and lose sync when doing so)
# 1.5 Animate freely, make sure the animation names are clear
# 2: Save the ".bbmodel" file into "plugins/Denizen/data/dmodels"
# 3: Load the model. For now, just do a command like "/ex run dmodels_load_bbmodel def:GOAT" but replace "GOAT" with the name of your model
#    This will output a resource pack to "plugins/Denizen/data/dmodels/res_pack/"
# 4: Load the resource pack on your client (or include it in your server's automatic resource pack)
# 5: Spawn your model and control it using the Denizen scripting API documented below
#
# #########
#
# API usage examples:
# # First load a model (in advance, not every time - you can use '/ex' to do this once after adding or modifying the .bbmodel file)
# - ~run dmodels_load_bbmodel def.model_name:goat
# # Then you can spawn it
# - run dmodels_spawn_model def.model_name:goat def.location:<player.location> save:spawned
# - define root <entry[spawned].created_queue.determination.first>
# # To move the whole model
# - teleport <[root]> <player.location>
# - run dmodels_reset_model_position def.root_entity:<[root]>
# # To start an automatic animation
# - run dmodels_animate def.root_entity:<[root]> def.animation:idle
# # To end an automatic animation
# - run dmodels_end_animation def.root_entity:<[root]>
# # To move the entity to a single frame of an animation (timespot is a decimal number of seconds from the start of the animation)
# - run dmodels_move_to_frame def.root_entity:<[root]> def.animation:idle def.timespot:0.5
# # To remove a model
# - run dmodels_delete def.root_entity:<[root]>
#
# #########
#
# API details:
#     Runnable Tasks:
#         dmodels_load_bbmodel
#             Usage: Loads a model from source ".bbmodel" file by name into server data (flags). Also builds the resource pack entries for it.
#                    Should be called well in advance, when the model is added or changed. Does not need to be re-called until the model is changed again.
#             Input definitions:
#                 model_name: The name of the model to load, must correspond to the relevant ".bbmodel" file.
#             This task should be ~waited for.
#         dmodels_spawn_model
#             Usage: Spawns a single instance of a model using real armor stand entities at a location.
#             Input definitions:
#                 model_name: The name of the model to spawn, must already have been loaded via 'dmodels_load_bbmodel'.
#                 location: The location to spawn the model at.
#                 tracking_range: (OPTIONAL) can override the global tracking_range setting in the config below per-model if desired.
#                 fake_to: (OPTIONAL) list of players to fake-spawn the model to. If left off, will use a real (serverside) entity spawn.
#             Supplies determination: EntityTag of the model root entity.
#         dmodels_delete
#             Usage: Deletes a spawned model.
#             Input definitions:
#                 root_entity: The root entity gotten from 'dmodels_spawn_model'.
#         dmodels_reset_model_position
#             Usage: Resets any animation data on a model, moving the model back to its default positioning.
#             Input definitions:
#                 root_entity: The root entity gotten from 'dmodels_spawn_model'.
#         dmodels_end_animation
#             Usage: Stops any animation currently playing on a model, and resets its position.
#             Input definitions:
#                 root_entity: The root entity gotten from 'dmodels_spawn_model'.
#         dmodels_animate
#             Usage: Starts a model animating the given animation, until the animation ends (if it does at all) or until the animation is changed or ended.
#             Input definitions:
#                 root_entity: The root entity gotten from 'dmodels_spawn_model'.
#                 animation: The name of the animation to play (as set in BlockBench).
#         dmodels_move_to_frame
#             Usage: Moves a model's position to a single frame of an animation. Not intended for external use except for debugging animation issues.
#             Input definitions:
#                 root_entity: The root entity gotten from 'dmodels_spawn_model'.
#                 animation: The name of the animation to play (as set in BlockBench).
#                 timespot: The time (in seconds) from the start of the animation to select as the frame.
#                 delay_pose: 'true' if playing fluidly to offset the pose application over time, 'false' to snap exactly to frame position.
#     Flags:
#         Every entity spawned by DModels has the flag 'dmodel_root', that refers up to the root entity.
#         The root entity has the following flags:
#             'dmodel_model_id': the name of the model used.
#             'dmodel_parts': a list of all part entities spawned.
#             'dmodel_anim_part.<ID_HERE>': a mapping of outline IDs to the part entity spawned for them.
#             'dmodels_animation_id': only if the model is animating automatically, contains the animation ID.
#             'dmodels_anim_time': only if the model is animating automatically, contains the progress through the current animation as a number representing time.
#        Additional flags are present on both the root and on parts, but are not considered API - use at your own risk.
#
################################################

dmodels_config:
    type: data
    debug: false
    # You can optionally set a tracking range for all properly-spawned model entities.
    # If set to 0, will use the server default for armor stands.
    # You can instead set to a value like 16 for only short range visibility, or 128 for super long range, or any other number.
    tracking_range: 0
    # You can choose which item is used to override for models.
    # Using a leather based item is recommended to allow for dynamically recoloring items.
    # Leather_Horse_Armor is ideal because other leather armors make noise when equipped.
    item: leather_horse_armor
