###########################
# This file is part of dModels / Denizen Models.
# Refer to the header of "dmodels_main.dsc" for more information.
###########################


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
    - define r1 <proc[dmodels_rot_quat].context[<[rot].x.mul[-1]>|x|<[loc]>]>
    - define r2 <proc[dmodels_rot_quat].context[<[rot].y.mul[-1]>|y|<[r1]>]>
    - determine <proc[dmodels_rot_quat].context[<[rot].z>|z|<[r2]>]>

# Angle = Angle in radians
# Axis = x,y,z
# Vector = Vector to rotate
dmodels_rot_quat:
    type: procedure
    debug: false
    definitions: angle|axis|vector
    script:
    #The vector to rotate
    - define p.w 0.0
    - define p.x <[vector].x>
    - define p.y <[vector].y>
    - define p.z <[vector].z>
    #The second quaternion
    - define q_2 <[p]>
    #Axis to rotate the vector
    - choose <[axis]>:
      - case x:
        - define axis <location[1,0,0].normalize>
      - case y:
        - define axis <location[0,1,0].normalize>
      - case z:
        - define axis <location[0,0,1].normalize>
    #Create quaternion from angle and axis
    - define q.w <[angle]>
    - define q.x <[axis].x>
    - define q.y <[axis].y>
    - define q.z <[axis].z>
    #Convert quaternion to unit norm quaternion
    - define angle <[q.w]>
    - define vec <location[<[q.x]>,<[q.y]>,<[q.z]>].normalize>
    - define w <[angle].mul[0.5].cos>
    - define vec <[vec].mul[<[angle].mul[0.5].sin>]>
    - define q.w <[w]>
    - define q.x <[vec].x>
    - define q.y <[vec].y>
    - define q.z <[vec].z>
    #Norm of the quaternion
    - define sc <[q.w].power[2]>
    - define vec <location[<[q.x]>,<[q.y]>,<[q.z]>]>
    - define im.x <[vec].x.power[2]>
    - define im.y <[vec].y.power[2]>
    - define im.z <[vec].z.power[2]>
    - define norm <[sc].add[<[im.x]>].add[<[im.y]>].add[<[im.z]>].sqrt>
    #Conjugate
    - define c_q.x <[q.x].mul[-1]>
    - define c_q.y <[q.y].mul[-1]>
    - define c_q.z <[q.z].mul[-1]>
    - define c_q.w <[q.w]>
    #Get the inverse of the quaternion
    - define norm <[norm].power[2]>
    - define norm <element[1].div[<[norm]>]>
    - define sc <[c_q.w].mul[<[norm]>]>
    - define cvec <location[<[c_q.x]>,<[c_q.y]>,<[c_q.z]>]>
    - define im.x <[cvec].x.mul[<[norm]>]>
    - define im.y <[cvec].y.mul[<[norm]>]>
    - define im.z <[cvec].z.mul[<[norm]>]>
    - define qInv.w <[sc]>
    - define qInv.x <[im.x]>
    - define qInv.y <[im.y]>
    - define qInv.z <[im.z]>
    #Quaternion multiplied by point(vector)
    #This method of quaternion multiplication is about 35% faster than the usual one
    #Q * P
    - define v <location[<[q.x]>,<[q.y]>,<[q.z]>]>
    - define v_2 <location[<[q_2.x]>,<[q_2.y]>,<[q_2.z]>]>
    - define scalar <[q.w].mul[<[q_2.w]>].sub[<[v].proc[pmodels_dot_product].context[<[v_2]>]>]>
    - define im <[v_2].mul[<[q.w]>].add[<[v].mul[<[q_2.w]>]>].add[<[v].proc[pmodels_cross_product].context[<[v_2]>]>]>
    - define nq.w <[scalar]>
    - define nq.x <[im].x>
    - define nq.y <[im].y>
    - define nq.z <[im].z>
    #New Q * Q-1
    - define q <[nq]>
    - define q_2 <[qInv]>
    - define v <location[<[q.x]>,<[q.y]>,<[q.z]>]>
    - define v_2 <location[<[q_2.x]>,<[q_2.y]>,<[q_2.z]>]>
    - define im <[v_2].mul[<[q.w]>].add[<[v].mul[<[q_2.w]>]>].add[<[v].proc[pmodels_cross_product].context[<[v_2]>]>]>
    - define rv.x <[im].x>
    - define rv.y <[im].y>
    - define rv.z <[im].z>
    - determine <location[<[rv.x]>,<[rv.y]>,<[rv.z]>]>

dmodels_dot_product:
    type: procedure
    debug: false
    definitions: a|b
    script:
    - determine <[a].x.mul[<[b].x>].add[<[a].y.mul[<[b].y>]>].add[<[a].z.mul[<[b].z>]>]>

dmodels_cross_product:
    type: procedure
    debug: false
    definitions: a|b
    script:
    - determine <[a].with_x[<[a].y.mul[<[b].z>].sub[<[a].z.mul[<[b].y>]>]>].with_y[<[a].z.mul[<[b].x>].sub[<[a].x.mul[<[b].z>]>]>].with_z[<[a].x.mul[<[b].y>].sub[<[a].y.mul[<[b].x>]>]>]>

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

dmodels_animator_world:
    type: world
    debug: false
    events:
        on tick server_flagged:dmodels_anim_active:
        - foreach <server.flag[dmodels_anim_active]> as:root:
            - if <[root].is_spawned||false>:
                - run dmodels_move_to_frame def.root_entity:<[root]> def.animation:<[root].flag[dmodels_animation_id]> def.timespot:<[root].flag[dmodels_anim_time].div[20]> def.delay_pose:true
                - flag <[root]> dmodels_anim_time:++
