
model_part_stand:
    type: entity
    debug: false
    entity_type: armor_stand
    mechanisms:
        marker: true
        gravity: false
        visible: false

spawn_model:
    type: task
    debug: false
    definitions: model_name|location
    script:
    - define location <[location].center>
    - define yamlid dmodels_<[model_name]>
    - define filename data/models/<[model_name]>.dmodel.yml
    - if !<server.has_file[<[filename]>]>:
        - debug error "Invalid model <[model_name]>, file does not exist: <[filename]>, cannot load"
        - stop
    - ~yaml id:<[yamlid]> load:<[filename]>
    - define parts <yaml[<[yamlid]>].read[models]>
    - flag server dmodels_data.model_<[model_name]>:<[parts]>
    - flag server dmodels_data.animations_<[model_name]>:<yaml[<[yamlid]>].read[animations]||<map>>
    - yaml unload id:<[yamlid]>
    - spawn model_part_stand <[location]> save:root
    - flag <entry[root].spawned_entity> dmodel_model_id:<[model_name]>
    - foreach <[parts]> key:id as:part:
        - if <[part.empty]||false>:
            - foreach next
        - define rots <[part.rotation].split[,].parse[to_radians]>
        # Idk wtf is with the scale here. It's somewhere in the range of 25 to 26. 25.45 seems closest in one of my tests,
        # but I think that's minecraft packet location imprecision at fault so it's possibly just 26?
        # Supposedly it's 25.6 according to external docs (16 * 1.6), but that also is wrong in my testing.
        - define offset <location[<[part.origin]>].div[25.6].rotate_around_y[<util.pi>]>
        - define pose <[rots].get[1].mul[-1]>,<[rots].get[2].mul[-1]>,<[rots].get[3]>
        - spawn model_part_stand[equipment=[helmet=<[part.item]>];armor_pose=[head=<[pose]>]] <[location].add[<[offset]>]> save:spawned
        - flag <entry[spawned].spawned_entity> dmodel_def_pose:<[pose]>
        - flag <entry[spawned].spawned_entity> dmodel_def_offset:<[offset]>
        - flag <entry[spawned].spawned_entity> dmodel_root:<entry[root].spawned_entity>
        - flag <entry[root].spawned_entity> dmodel_parts:->:<entry[spawned].spawned_entity>
        - flag <entry[root].spawned_entity> dmodel_anim_part.<[id]>:->:<entry[spawned].spawned_entity>
    - foreach <[parts]> key:id as:part:
        - foreach <[part.pairs]> as:pair_id:
            - flag <entry[root].spawned_entity> dmodel_anim_part.<[id]>:|:<entry[root].spawned_entity.flag[dmodel_anim_part.<[pair_id]>]||<list>>
    - determine <entry[root].spawned_entity>

dmodels_correct_to_default_position:
    type: task
    debug: false
    definitions: root_entity
    script:
    - foreach <[root_entity].flag[dmodel_parts]> as:part:
        - adjust <[part]> armor_pose:[head=<[part].flag[dmodel_def_pose]>]
        - teleport <[part]> <[root_entity].location.add[<[part].flag[dmodel_def_offset]>]>

dmodels_animate:
    type: task
    debug: false
    definitions: root_entity|animation
    script:
    - run dmodels_correct_to_default_position def.root_entity:<[root_entity]>
    - define animation_data <server.flag[dmodels_data.animations_<[root_entity].flag[dmodel_model_id]>.<[animation]>]||null>
    - if <[animation_data]> == null:
        - debug error "[DModels] Cannot animate entity <[root_entity].uuid> due to model <[root_entity].flag[dmodel_model_id]> not having an animation named <[animation]>"
        - stop
    - flag <[root_entity]> dmodels_animation_id:<[animation]>
    - flag <[root_entity]> dmodels_anim_time:0
    - flag server dmodels_anim_active.<[root_entity].uuid>

dmodels_move_to_frame:
    type: task
    debug: false
    definitions: root_entity|animation|timespot
    script:
    - define animation_data <server.flag[dmodels_data.animations_<[root_entity].flag[dmodel_model_id]>.<[animation]>]||null>
    - if <[timespot]> > <[animation_data.length]>:
        - choose <[animation_data.loop]>:
            - case loop:
                - define timespot <[timespot].mod[<[animation_data.length]>]>
            - case once:
                - flag server dmodels_anim_active.<[root_entity].uuid>:!
                - if <[root_entity].has_flag[dmodels_default_animation]>:
                    - run dmodels_animate def.root_entity:<[root_entity]> def.animation:<[root_entity].flag[dmodels_default_animation]>
                - else:
                    - run dmodels_correct_to_default_position def.root_entity:<[root_entity]>
                - stop
            - case hold:
                - define timespot <[animation_data.length]>
                - flag server dmodels_anim_active.<[root_entity].uuid>:!
    - foreach <[animation_data.animators]> key:part_id as:animator:
        - define ents <[root_entity].flag[dmodel_anim_part.<[part_id]>]||<list>>
        - if <[ents].is_empty>:
            - foreach next
        - foreach position|rotation as:channel:
            - define relevant_frames <[animator.frames].filter[get[channel].equals[<[channel]>]]>
            - define before_frame <[relevant_frames].filter[get[time].is_less_than_or_equal_to[<[timespot]>]].last||null>
            - define after_frame <[relevant_frames].filter[get[time].is_more_than_or_equal_to[<[timespot]>]].first||null>
            - if <[before_frame]> == null:
                - define before_frame <[after_frame]>
            - if <[after_frame]> == null:
                - define after_frame <[before_frame]>
            - if <[before_frame]> == null:
                - foreach next
            - define time_range <[after_frame.time].sub[<[before_frame.time]>]>
            - if <[time_range]> == 0:
                - define time_percent 0
            - else:
                - define time_percent <[timespot].sub[<[before_frame.time]>].div[<[time_range]>]>
            - choose <[before_frame.interpolation]>:
                - case catmullrom:
                    - define before_extra <[relevant_frames].filter[get[time].is_less_than[<[before_frame.time]>]].last||null>
                    - if <[before_extra]> == null:
                        - define before_extra <[before_frame]>
                    - define after_extra <[relevant_frames].filter[get[time].is_more_than[<[after_frame.time]>]].first||null>
                    - if <[after_extra]> == null:
                        - define after_extra <[after_frame]>
                    - define p0 <[before_extra.data].as_location>
                    - define p1 <[before_frame.data].as_location>
                    - define p2 <[after_frame.data].as_location>
                    - define p3 <[after_extra.data].as_location>
                    - define data <proc[dmodels_catmullrom_proc].context[<[p0]>|<[p1]>|<[p2]>|<[p3]>|<[time_percent]>]>
                - case linear:
                    - define data <[after_frame.data].as_location.sub[<[before_frame.data]>].mul[<[time_percent]>].add[<[before_frame.data]>].xyz>
                - case step:
                    - define data <[before_frame.data]>
            - foreach <[ents]> as:ent:
                - choose <[channel]>:
                    - case position:
                        - teleport <[ent]> <[root_entity].location.add[<[ent].flag[dmodel_def_offset].add[<[data].as_location.div[25.6]>]>]>
                    - case rotation:
                        - define radian_rot <[data].as_location.xyz.split[,].parse[to_radians].separated_by[,]>
                        - adjust <[ent]> armor_pose:[head=<[ent].flag[dmodel_def_pose].as_location.add[<[radian_rot]>].xyz>]

dmodels_catmullrom_get_t:
    type: procedure
    debug: false
    definitions: t|p0|p1
    script:
    # This is more complex for different alpha values, but alpha=1 compresses down to a '.length' call conveniently
    - determine <[p1].sub[<[p0]>].length.add[<[t]>]>

dmodels_catmullrom_proc:
    type: procedure
    debug: false
    definitions: p0|p1|p2|p3|t
    script:
    # TODO: Validate this mess
    - define t0 0
    - define t1 <proc[dmodels_catmullrom_get_t].context[0|<[p0]>|<[p1]>]>
    - define t2 <proc[dmodels_catmullrom_get_t].context[<[t1]>|<[p1]>|<[p2]>]>
    - define t3 <proc[dmodels_catmullrom_get_t].context[<[t2]>|<[p2]>|<[p3]>]>
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
        on server start priority:-1000:
        # Cleanup
        - flag server dmodels_data:!
        - flag server dmodels_anim_active:!
        on tick server_flagged:dmodels_anim_active:
        - foreach <server.flag[dmodels_anim_active]> key:root_id:
            - define root <entity[<[root_id]>]||null>
            - if <[root].is_spawned||false>:
                - run dmodels_move_to_frame def.root_entity:<[root]> def.animation:<[root].flag[dmodels_animation_id]> def.timespot:<[root].flag[dmodels_anim_time].div[20]>
                - flag <[root]> dmodels_anim_time:++