# +---------------------------
# |
# | D e n i z en   M o d e l s
# | AKA DModels - dynamically animated models in minecraft
# |
# +---------------------------
#
# @author mcmonkey
# @date 2022/06/01
# @updated 2022/06/13
# @denizen-build REL-1772
# @script-version 1.3
#
# This takes BlockBench "BBModel" files, converts them (via external program) to resource pack + Denizen-compatible file,
# then is able to display them in minecraft and even animate them, by spawning and moving invisible armor stands with resource pack items on their heads.
#
# Installation:
# 1: Add "models.dsc" to your "plugins/Denizen/scripts" and "/ex reload"
# 2: Make sure you have DenizenModelsConverter.exe on hand, either downloaded or compiled yourself from https://github.com/mcmonkeyprojects/DenizenModels
# 3: Note that you must know the basics of operating resource packs - the pack content will be generated for you, but you must know how to configure the "mcmeta" pack file and how to install a pack on your client
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
#    (for example, if you have a bone pivot point in the center of a block, but the block's own pivot point is left at default 0,0,0, this can lead to the armor stand having to move and rotate at the same time, and lose sync when doing so)
# 1.5 Animate freely, make sure the animation names are clear
# 2: Save the ".bbmodel" file
# 3: Use the DenizenModelsConverter program to convert the bbmodel to a ".dmodel.yml" and a resource pack
# 4: Save the ".dmodel.yml" file into "plugins/Denizen/data/models"
# 5: Load the resource pack on your client (or include it in your server's automatic resource pack)
# 6: Spawn your model and control it using the Denizen scripting API documented below
#
# #########
#
# API usage examples:
# # First load a model
# - ~run dmodels_load_model def.model_name:goat
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
#         dmodels_load_model
#             Usage: Loads a model from source data by name into server memory (flags).
#             Input definitions:
#                 model_name: The name of the model to load, must correspond to the relevant ".dmodel.yml" file.
#         dmodels_spawn_model
#             Usage: Spawns a single instance of a model using real armor stand entities at a location.
#             Input definitions:
#                 model_name: The name of the model to spawn, must already be loaded via 'dmodels_load_model'.
#                 location: The location to spawn the model at.
#                 tracking_range: (OPTIONAL) can override the global tracking_range setting in the config below per-model if desired.
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
#
################################################

dmodels_config:
    type: data
    debug: false
    # You can optionally set a tracking range for all properly-spawned model entities.
    # If set to 0, will use the server default for armor stands.
    # You can instead set to a value like 16 for only short range visibility, or 128 for super long range, or any other number.
    tracking_range: 0
