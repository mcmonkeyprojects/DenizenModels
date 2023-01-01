###########################
# This file is part of dModels / Denizen Models.
# Refer to the header of "dmodels_main.dsc" for more information.
###########################


dmodel_part_stand:
    type: entity
    debug: false
    entity_type: armor_stand
    mechanisms:
        marker: true
        gravity: false
        visible: false
        is_small: true

dmodels_spawn_model:
    type: task
    debug: false
    definitions: model_name|location|tracking_range|fake_to
    script:
    - if !<server.has_flag[dmodels_data.model_<[model_name]>]>:
        - debug error "[DModels] cannot spawn model <[model_name]>, model not loaded"
        - stop
    # 0.72 is arbitrary but seems to align the bottom to the ground from visual testing
    - define center <[location].with_pitch[0].below[0.72]>
    - define yaw_mod <[location].yaw.add[180].to_radians>
    - if <[fake_to].exists>:
        - fakespawn dmodel_part_stand <[location]> players:<[fake_to]> save:root d:infinite
        - define root <entry[root].faked_entity>
    - else:
        - spawn dmodel_part_stand <[location]> save:root
        - define root <entry[root].spawned_entity>
    - flag <[root]> dmodel_model_id:<[model_name]>
    - flag <[root]> dmodel_root:<[root]>
    - define parentage <map>
    - define model_data <server.flag[dmodels_data.model_<[model_name]>]>
    - define tracking_range <[tracking_range].if_null[<script[dmodels_config].data_key[tracking_range]>]>
    - foreach <[model_data]> key:id as:part:
        - define rots <[part.rotation].split[,].parse[to_radians]>
        - define pose <[rots].get[1].mul[-1]>,<[rots].get[2].mul[-1]>,<[rots].get[3]>
        - define parent_id <[part.parent]>
        - define parent_pos <location[<[parentage.<[parent_id]>.position]||0,0,0>]>
        - define parent_rot <location[<[parentage.<[parent_id]>.rotation]||0,0,0>]>
        - define parent_offset <location[<[parentage.<[parent_id]>.offset]||0,0,0>]>
        - define parent_raw_offset <[model_data.<[parent_id]>.origin]||0,0,0>
        - define rel_offset <location[<[part.origin]>].sub[<[parent_raw_offset]>]>
        - define rot_offset <[rel_offset].proc[dmodels_rot_proc].context[<[parent_rot]>]>
        - define new_pos <[rot_offset].as[location].add[<[parent_pos]>]>
        - define new_rot <[parent_rot].add[<[pose]>]>
        - define parentage.<[id]>.position <[new_pos]>
        - define parentage.<[id]>.rotation <[new_rot]>
        - define parentage.<[id]>.offset <[rot_offset].add[<[parent_offset]>]>
        - if !<[part.item].exists>:
            - foreach next
        - define to_spawn_ent dmodel_part_stand[equipment=[helmet=<[part.item]>];armor_pose=[head=<[new_rot].xyz>]]
        - define to_spawn_loc <[center].add[<[new_pos].div[16].rotate_around_y[<[yaw_mod].mul[-1]>]>]>
        - if <[fake_to].exists>:
            - fakespawn <[to_spawn_ent]> <[to_spawn_loc]> players:<[fake_to]> save:spawned d:infinite
            - define spawned <entry[spawned].faked_entity>
        - else:
            - spawn <[to_spawn_ent]> <[to_spawn_loc]> save:spawned
            - define spawned <entry[spawned].spawned_entity>
        - if <[tracking_range]> > 0:
            - adjust <[spawned]> tracking_range:<[tracking_range]>
        - flag <[spawned]> dmodel_def_pose:<[new_rot].xyz>
        - flag <[spawned]> dmodel_def_offset:<[new_pos].div[16]>
        - flag <[spawned]> dmodel_root:<[root]>
        - flag <[root]> dmodel_parts:->:<[spawned]>
        - flag <[root]> dmodel_anim_part.<[id]>:->:<[spawned]>
    - determine <[root]>

dmodels_delete:
    type: task
    debug: false
    definitions: root_entity
    script:
    - if !<[root_entity].is_truthy> || !<[root_entity].has_flag[dmodel_model_id]||false>:
        - debug error "[DModels] invalid delete root_entity <[root_entity]>"
        - stop
    - flag server dmodels_anim_active.<[root_entity].uuid>:!
    - flag server dmodels_attached.<[root_entity].uuid>:!
    - remove <[root_entity].flag[dmodel_parts]>
    - remove <[root_entity]>

dmodels_reset_model_position:
    type: task
    debug: false
    definitions: root_entity
    script:
    - define center <[root_entity].location.with_pitch[0].below[0.72]>
    - define yaw_mod <[root_entity].location.yaw.add[180].to_radians>
    - foreach <[root_entity].flag[dmodel_parts]> as:part:
        - adjust <[part]> armor_pose:[head=<[part].flag[dmodel_def_pose]>]
        - teleport <[part]> <[center].add[<[part].flag[dmodel_def_offset].rotate_around_y[<[yaw_mod].mul[-1]>]>]>
