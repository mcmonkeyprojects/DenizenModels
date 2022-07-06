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
        - fakespawn dmodel_part_stand <[location]> save:root d:infinite
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
        - define new_pos <[rot_offset].as_location.add[<[parent_pos]>]>
        - define new_rot <[parent_rot].add[<[pose]>]>
        - define parentage.<[id]>.position <[new_pos]>
        - define parentage.<[id]>.rotation <[new_rot]>
        - define parentage.<[id]>.offset <[rot_offset].add[<[parent_offset]>]>
        - if !<[part.item].exists>:
            - foreach next
        - define to_spawn_ent dmodel_part_stand[equipment=[helmet=<[part.item]>];armor_pose=[head=<[new_rot].xyz>]]
        - define to_spawn_loc <[center].add[<[new_pos].div[16].rotate_around_y[<[yaw_mod].mul[-1]>]>]>
        - if <[fake_to].exists>:
            - fakespawn <[to_spawn_ent]> <[to_spawn_loc]> save:spawned d:infinite
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

dmodels_end_animation:
    type: task
    debug: false
    definitions: root_entity
    script:
    - flag <[root_entity]> dmodels_animation_id:!
    - flag <[root_entity]> dmodels_anim_time:0
    - flag server dmodels_anim_active.<[root_entity].uuid>:!
    - run dmodels_reset_model_position def.root_entity:<[root_entity]>

dmodels_animate:
    type: task
    debug: false
    definitions: root_entity|animation
    script:
    - run dmodels_reset_model_position def.root_entity:<[root_entity]>
    - define animation_data <server.flag[dmodels_data.animations_<[root_entity].flag[dmodel_model_id]>.<[animation]>]||null>
    - if <[animation_data]> == null:
        - debug error "[DModels] Cannot animate entity <[root_entity].uuid> due to model <[root_entity].flag[dmodel_model_id]> not having an animation named <[animation]>"
        - stop
    - flag <[root_entity]> dmodels_animation_id:<[animation]>
    - flag <[root_entity]> dmodels_anim_time:0
    - flag server dmodels_anim_active.<[root_entity].uuid>:<[root_entity]>

dmodels_move_to_frame:
    type: task
    debug: false
    definitions: root_entity|animation|timespot|delay_pose
    script:
    - define model_data <server.flag[dmodels_data.model_<[root_entity].flag[dmodel_model_id]>]>
    - define animation_data <server.flag[dmodels_data.animations_<[root_entity].flag[dmodel_model_id]>.<[animation]>]>
    - if <[timespot]> > <[animation_data.length]>:
        - choose <[animation_data.loop]>:
            - case loop:
                - define timespot <[timespot].mod[<[animation_data.length]>]>
            - case once:
                - flag server dmodels_anim_active.<[root_entity].uuid>:!
                - if <[root_entity].has_flag[dmodels_default_animation]>:
                    - run dmodels_animate def.root_entity:<[root_entity]> def.animation:<[root_entity].flag[dmodels_default_animation]>
                - else:
                    - run dmodels_reset_model_position def.root_entity:<[root_entity]>
                - stop
            - case hold:
                - define timespot <[animation_data.length]>
                - flag server dmodels_anim_active.<[root_entity].uuid>:!
    - define center <[root_entity].location.with_pitch[0].below[0.72]>
    - define yaw_mod <[root_entity].location.yaw.add[180].to_radians>
    - define parentage <map>
    - foreach <[animation_data.animators]> key:part_id as:animator:
        - define framedata.position 0,0,0
        - define framedata.rotation 0,0,0
        - foreach position|rotation as:channel:
            - define relevant_frames <[animator.frames].filter[get[channel].equals[<[channel]>]]>
            - define before_frame <[relevant_frames].filter[get[time].is_less_than_or_equal_to[<[timespot]>]].last||null>
            - define after_frame <[relevant_frames].filter[get[time].is_more_than_or_equal_to[<[timespot]>]].first||null>
            - if <[before_frame]> == null:
                - define before_frame <[after_frame]>
            - if <[after_frame]> == null:
                - define after_frame <[before_frame]>
            - if <[before_frame]> == null:
                - define data 0,0,0
            - else:
                - define time_range <[after_frame.time].sub[<[before_frame.time]>]>
                - if <[time_range]> == 0:
                    - define time_percent 0
                - else:
                    - define time_percent <[timespot].sub[<[before_frame.time]>].div[<[time_range]>]>
                - choose <[before_frame.interpolation]>:
                    - case catmullrom:
                        - define before_extra <[relevant_frames].filter[get[time].is_less_than[<[before_frame.time]>]].last||null>
                        - if <[before_extra]> == null:
                            - define before_extra <[animation_data.loop].equals[loop].if_true[<[relevant_frames].last>].if_false[<[before_frame]>]>
                        - define after_extra <[relevant_frames].filter[get[time].is_more_than[<[after_frame.time]>]].first||null>
                        - if <[after_extra]> == null:
                            - define after_extra <[animation_data.loop].equals[loop].if_true[<[relevant_frames].first>].if_false[<[after_frame]>]>
                        - define p0 <[before_extra.data].as_location>
                        - define p1 <[before_frame.data].as_location>
                        - define p2 <[after_frame.data].as_location>
                        - define p3 <[after_extra.data].as_location>
                        - define data <proc[dmodels_catmullrom_proc].context[<[p0]>|<[p1]>|<[p2]>|<[p3]>|<[time_percent]>]>
                    - case linear:
                        - define data <[after_frame.data].as_location.sub[<[before_frame.data]>].mul[<[time_percent]>].add[<[before_frame.data]>].xyz>
                    - case step:
                        - define data <[before_frame.data]>
            - define framedata.<[channel]> <[data]>
        - define this_part <[model_data.<[part_id]>]>
        - define this_rots <[this_part.rotation].split[,].parse[to_radians]>
        - define pose <[this_rots].get[1].mul[-1]>,<[this_rots].get[2].mul[-1]>,<[this_rots].get[3]>
        - define parent_id <[this_part.parent]>
        - define parent_pos <location[<[parentage.<[parent_id]>.position]||0,0,0>]>
        - define parent_rot <location[<[parentage.<[parent_id]>.rotation]||0,0,0>]>
        - define parent_offset <location[<[parentage.<[parent_id]>.offset]||0,0,0>]>
        - define parent_raw_offset <[model_data.<[parent_id]>.origin]||0,0,0>
        - define rel_offset <location[<[this_part.origin]>].sub[<[parent_raw_offset]>]>
        - define rot_offset <[rel_offset].proc[dmodels_rot_proc].context[<[parent_rot]>]>
        - define new_pos <[framedata.position].as_location.proc[dmodels_rot_proc].context[<[parent_rot]>].add[<[rot_offset]>].add[<[parent_pos]>]>
        - define new_rot <[framedata.rotation].as_location.add[<[parent_rot]>].add[<[pose]>]>
        - define parentage.<[part_id]>.position <[new_pos]>
        - define parentage.<[part_id]>.rotation <[new_rot]>
        - define parentage.<[part_id]>.offset <[rot_offset].add[<[parent_offset]>]>
        - foreach <[root_entity].flag[dmodel_anim_part.<[part_id]>]||<list>> as:ent:
            - teleport <[ent]> <[center].add[<[new_pos].div[16].rotate_around_y[<[yaw_mod].mul[-1]>]>]>
            - adjust <[ent]> reset_client_location
            - define radian_rot <[new_rot].xyz.split[,]>
            - define pose <[radian_rot].get[1]>,<[radian_rot].get[2]>,<[radian_rot].get[3]>
            - if <[delay_pose]>:
                - adjust <[ent]> armor_pose:[head=<[ent].flag[dmodels_next_pose].if_null[<[ent].flag[dmodel_def_pose]>]>]
                - flag <[ent]> dmodels_next_pose:<[pose]>
            - else:
                - adjust <[ent]> armor_pose:[head=<[pose]>]
                - adjust <[ent]> send_update_packets

dmodels_rot_proc:
    type: procedure
    debug: false
    definitions: loc|rot
    script:
    - determine <[loc].rotate_around_x[<[rot].x.mul[-1]>].rotate_around_y[<[rot].y.mul[-1]>].rotate_around_z[<[rot].z>]>

dmodels_catmullrom_get_t:
    type: procedure
    debug: false
    definitions: t|p0|p1
    script:
    # This is more complex for different alpha values, but alpha=1 compresses down to a '.vector_length' call conveniently
    - determine <[p1].sub[<[p0]>].vector_length.add[<[t]>]>

dmodels_catmullrom_proc:
    type: procedure
    debug: false
    definitions: p0|p1|p2|p3|t
    script:
    # Zero distances are impossible to calculate
    - if <[p2].sub[<[p1]>].vector_length> < 0.01:
        - determine <[p2]>
    # Based on https://en.wikipedia.org/wiki/Centripetal_Catmull%E2%80%93Rom_spline#Code_example_in_Unreal_C++
    # With safety checks added for impossible situations
    - define t0 0
    - define t1 <proc[dmodels_catmullrom_get_t].context[0|<[p0]>|<[p1]>]>
    - define t2 <proc[dmodels_catmullrom_get_t].context[<[t1]>|<[p1]>|<[p2]>]>
    - define t3 <proc[dmodels_catmullrom_get_t].context[<[t2]>|<[p2]>|<[p3]>]>
    # Divide-by-zero safety check
    - if <[t1].abs> < 0.001 || <[t2].sub[<[t1]>].abs> < 0.001 || <[t2].abs> < 0.001 || <[t3].sub[<[t1]>].abs> < 0.001:
        - determine <[p2].sub[<[p1]>].mul[<[t]>].add[<[p1]>]>
    - define t <[t2].sub[<[t1]>].mul[<[t]>].add[<[t1]>]>
    # ( t1-t )/( t1-t0 )*p0 + ( t-t0 )/( t1-t0 )*p1;
    - define a1 <[p0].mul[<[t1].sub[<[t]>].div[<[t1]>]>].add[<[p1].mul[<[t].div[<[t1]>]>]>]>
    # ( t2-t )/( t2-t1 )*p1 + ( t-t1 )/( t2-t1 )*p2;
    - define a2 <[p1].mul[<[t2].sub[<[t]>].div[<[t2].sub[<[t1]>]>]>].add[<[p2].mul[<[t].sub[<[t1]>].div[<[t2].sub[<[t1]>]>]>]>]>
    # FVector A3 = ( t3-t )/( t3-t2 )*p2 + ( t-t2 )/( t3-t2 )*p3;
    - define a3 <[a1].mul[<[t2].sub[<[t]>].div[<[t2]>]>].add[<[a2].mul[<[t].div[<[t2]>]>]>]>
    # FVector B1 = ( t2-t )/( t2-t0 )*A1 + ( t-t0 )/( t2-t0 )*A2;
    - define b1 <[a1].mul[<[t2].sub[<[t]>].div[<[t2]>]>].add[<[a2].mul[<[t].div[<[t2]>]>]>]>
    # FVector B2 = ( t3-t )/( t3-t1 )*A2 + ( t-t1 )/( t3-t1 )*A3;
    - define b2 <[a2].mul[<[t3].sub[<[t]>].div[<[t3].sub[<[t1]>]>]>].add[<[a3].mul[<[t].sub[<[t1]>].div[<[t3].sub[<[t1]>]>]>]>]>
    # FVector C  = ( t2-t )/( t2-t1 )*B1 + ( t-t1 )/( t2-t1 )*B2;
    - determine <[b1].mul[<[t2].sub[<[t]>].div[<[t2].sub[<[t1]>]>]>].add[<[b2].mul[<[t].sub[<[t1]>].div[<[t2].sub[<[t1]>]>]>]>]>

dmodels_animator:
    type: world
    debug: false
    events:
        on tick server_flagged:dmodels_anim_active:
        - foreach <server.flag[dmodels_anim_active]> as:root:
            - if <[root].is_spawned||false>:
                - run dmodels_move_to_frame def.root_entity:<[root]> def.animation:<[root].flag[dmodels_animation_id]> def.timespot:<[root].flag[dmodels_anim_time].div[20]> def.delay_pose:true
                - flag <[root]> dmodels_anim_time:++
