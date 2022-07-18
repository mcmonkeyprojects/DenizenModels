###########################
# This file is part of dModels / Denizen Models.
# Refer to the header of "dmodels_main.dsc" for more information.
###########################


dmodels_load_bbmodel:
    type: task
    debug: false
    definitions: model_name
    script:
    # =============== Prep ===============
    - define pack_root <script[dmodels_config].data_key[resource_pack_path]>
    - define models_root <[pack_root]>/assets/minecraft/models/item/dmodels/<[model_name]>
    - define textures_root <[pack_root]>/assets/minecraft/textures/dmodels/<[model_name]>
    - define item_validate <item[<script[dmodels_config].data_key[item]>]||null>
    - if <[item_validate]> == null:
      - debug error "[DModels] Item must be valid Example: potion"
      - stop
    - define override_item_filepath <[pack_root]>/assets/minecraft/models/item/<script[dmodels_config].data_key[item]>.json
    - define file data/dmodels/<[model_name]>.bbmodel
    - define scale_factor <element[2.285].div[4]>
    - define mc_texture_data <map>
    - flag server dmodels_data.temp_<[model_name]>:!
    # =============== BBModel loading and validation ===============
    - if !<util.has_file[<[file]>]>:
        - debug error "[DModels] Cannot load model '<[model_name]>' because file '<[file]>' does not exist."
        - stop
    - ~fileread path:<[file]> save:filedata
    - define data <util.parse_yaml[<entry[filedata].data.utf8_decode||>]||>
    - if !<[data].is_truthy>:
        - debug error "[DModels] Something went wrong trying to load BBModel data for model '<[model_name]>' - fileread invalid."
        - stop
    - define meta <[data.meta]||>
    - define resolution <[data.resolution]||>
    - if !<[meta].is_truthy> || !<[resolution].is_truthy>:
        - debug error "[DModels] Something went wrong trying to load BBModel data for model '<[model_name]>' - possibly not a valid BBModel file?"
        - stop
    - if !<[data.elements].exists>:
        - debug error "[DModels] Can't load bbmodel for '<[model_name]>' - file has no elements?"
        - stop
    # =============== Pack validation ===============
    - if !<server.has_flag[<[pack_root]>/pack.mcmeta]>:
        - run dmodels_multiwaitable_filewrite def.key:<[model_name]> def.path:<[pack_root]>/pack.mcmeta def.data:<map.with[pack].as[<map[pack_format=8;description=dModels_AutoPack_Default]>].to_json[native_types=true;indent=4].utf8_encode>
    # =============== Textures loading ===============
    - define tex_id 0
    - foreach <[data.textures]||<list>> as:texture:
        - define texname <[texture.name]>
        - if <[texname].ends_with[.png]>:
            - define texname <[texname].before[.png]>
        - define raw_source <[texture.source]||>
        - if !<[raw_source].starts_with[data:image/png;base64,]>:
            - debug error "[DModels] Can't load bbmodel for '<[model_name]>': invalid texture source data."
            - stop
        - define texture_output_path <[textures_root]>/<[texname]>.png
        - run dmodels_multiwaitable_filewrite def.key:<[model_name]> def.path:<[texture_output_path]> def.data:<[raw_source].after[,].base64_to_binary>
        - define proper_path dmodels/<[model_name]>/<[texname]>
        - define mc_texture_data.<[tex_id]> <[proper_path]>
        - if <[texture.particle]||false>:
            - define mc_texture_data.particle <[proper_path]>
        - define tex_id:++
    # =============== Elements loading ===============
    - foreach <[data.elements]> as:element:
        - if <[element.type]||cube> != cube:
            - foreach next
        - define element.origin <[element.origin].separated_by[,]||0,0,0>
        - define element.rotation <[element.rotation].separated_by[,]||0,0,0>
        - define flagname dmodels_data.model_<[model_name]>.namecounter_element.<[element.name]>
        - flag server <[flagname]>:++
        - if <server.flag[<[flagname]>]> > 1:
            - define element.name <[element.name]><server.flag[<[flagname]>]>
        - flag server dmodels_data.temp_<[model_name]>.raw_elements.<[element.uuid]>:<[element]>
    # =============== Outlines loading ===============
    - define root_outline null
    - foreach <[data.outliner]||<list>> as:outliner:
        - if <[outliner].matches_character_set[abcdef0123456789-]>:
            - if <[root_outline]> == null:
                - definemap root_outline name:__root__ origin:0,0,0 rotation:0,0,0 uuid:<util.random_uuid>
                - flag server dmodels_data.temp_<[model_name]>.raw_outlines.<[root_outline.uuid]>:<[root_outline]>
            - run dmodels_loader_addchild def.model_name:<[model_name]> def.parent:<[root_outline]> def.child:<[outliner]>
        - else:
            - define outliner.parent:none
            - run dmodels_loader_readoutline def.model_name:<[model_name]> def.outline:<[outliner]>
    # =============== Clear out pre-existing data ===============
    - flag server dmodels_data.model_<[model_name]>:!
    - flag server dmodels_data.animations_<[model_name]>:!
    # =============== Animations loading ===============
    - foreach <[data.animations]||<list>> as:animation:
        - define animation_list.<[animation.name]>.loop <[animation.loop]>
        - define animation_list.<[animation.name]>.override <[animation.override]>
        - define animation_list.<[animation.name]>.anim_time_update <[animation.anim_time_update]>
        - define animation_list.<[animation.name]>.blend_weight <[animation.blend_weight]>
        - define animation_list.<[animation.name]>.length <[animation.length]>
        - define animator_data <[animation.animators]>
        - foreach <server.flag[dmodels_data.temp_<[model_name]>.raw_outlines]> key:o_uuid as:outline_data:
            - define animator <[animator_data.<[o_uuid]>]||null>
            - if <[animator]> == null:
                - define animation_list.<[animation.name]>.animators.<[o_uuid]>.frames <list>
            - else:
                - foreach <[animator.keyframes]> as:keyframe:
                    - definemap anim_map channel:<[keyframe.channel]> time:<[keyframe.time]> interpolation:<[keyframe.interpolation]>
                    - define data_points <[keyframe.data_points].first>
                    - if <[anim_map.channel]> == rotation:
                        - define anim_map.data <[data_points.x].to_radians>,<[data_points.y].to_radians>,<[data_points.z].to_radians>
                    - else:
                        - define anim_map.data <[data_points.x]>,<[data_points.y]>,<[data_points.z]>
                    - define animation_list.<[animation.name]>.animators.<[o_uuid]>.frames:->:<[anim_map]>
                # Sort frames by time (why is this not done by default? BlockBench is weird)
                - define animation_list.<[animation.name]>.animators.<[o_uuid]>.frames <[animation_list.<[animation.name]>.animators.<[o_uuid]>.frames].sort_by_value[get[time]]>
    - if <[animation_list].any||false>:
        - flag server dmodels_data.animations_<[model_name]>:<[animation_list]>
    # =============== Item model file generation ===============
    - if <util.has_file[<[override_item_filepath]>]>:
        - ~fileread path:<[override_item_filepath]> save:override_item
        - define override_item_data <util.parse_yaml[<entry[override_item].data.utf8_decode>]>
    - else:
        - definemap override_item_data parent:minecraft:item/generated textures:<map[layer0=minecraft:item/<script[dmodels_config].data_key[item]>]>
    - define overrides_changed false
    - foreach <server.flag[dmodels_data.temp_<[model_name]>.raw_outlines]> as:outline:
        - define outline_origin <location[<[outline.origin]>]>
        - define model_json.textures <[mc_texture_data]>
        - define model_json.elements <list>
        - define child_count 0
        #### Element building
        - foreach <server.flag[dmodels_data.temp_<[model_name]>.raw_elements]> as:element:
            - if <[outline.children].contains[<[element.uuid]>]||false>:
                - define child_count:++
                - define jsonelement.name <[element.name]>
                - define rot <location[<[element.rotation]>]>
                - define jsonelement.from <location[<[element.from].separated_by[,]>].sub[<[outline_origin]>].mul[<[scale_factor]>].xyz.split[,]>
                - define jsonelement.to <location[<[element.to].separated_by[,]>].sub[<[outline_origin]>].mul[<[scale_factor]>].xyz.split[,]>
                - define jsonelement.rotation.origin <location[<[element.origin]>].sub[<[outline_origin]>].mul[<[scale_factor]>].xyz.split[,]>
                - if <[rot].x> != 0:
                    - define jsonelement.rotation.axis x
                    - define jsonelement.rotation.angle <[rot].x>
                - else if <[rot].z> != 0:
                    - define jsonelement.rotation.axis z
                    - define jsonelement.rotation.angle <[rot].z>
                - else:
                    - define jsonelement.rotation.axis y
                    - define jsonelement.rotation.angle <[rot].y>
                - foreach <[element.faces]> key:faceid as:face:
                    - define jsonelement.faces.<[faceid]> <[face].proc[dmodels_facefix].context[<[resolution]>]>
                - define model_json.elements:->:<[jsonelement]>
        - define outline.children:!
        - if <[child_count]> > 0:
            #### Item override building
            - definemap json_group name:<[outline.name]> color:0 children:<util.list_numbers[from=0;to=<[child_count]>]> origin:<[outline_origin].mul[<[scale_factor]>].xyz.split[,]>
            - define model_json.groups <list[<[json_group]>]>
            - define model_json.display.head.translation <list[32|25|32]>
            - define model_json.display.head.scale <list[4|4|4]>
            - define modelpath item/dmodels/<[model_name]>/<[outline.name]>
            - run dmodels_multiwaitable_filewrite def.key:<[model_name]> def.path:<[models_root]>/<[outline.name]>.json def.data:<[model_json].to_json[native_types=true;indent=4].utf8_encode>
            - define cmd 0
            - define min_cmd 1000
            - foreach <[override_item_data.overrides]||<list>> as:override:
                - if <[override.model]> == <[modelpath]>:
                    - define cmd <[override.predicate.custom_model_data]>
                - define min_cmd <[min_cmd].max[<[override.predicate.custom_model_data].add[1]||1000>]>
            - if <[cmd]> == 0:
                - define cmd <[min_cmd]>
                - define override_item_data.overrides:->:<map[predicate=<map[custom_model_data=<[cmd]>]>].with[model].as[<[modelpath]>]>
                - define overrides_changed true
            - define outline.item <script[dmodels_config].data_key[item]>[custom_model_data=<[cmd]>]
        # This sets the actual live usage flag data
        - flag server dmodels_data.model_<[model_name]>.<[outline.uuid]>:<[outline]>
    - if <[overrides_changed]>:
        - run dmodels_multiwaitable_filewrite def.key:<[model_name]> def.path:<[override_item_filepath]> def.data:<[override_item_data].to_json[native_types=true;indent=4].utf8_encode>
    # Ensure all filewrites are done before ending the task
    - waituntil rate:1t max:5m <server.flag[dmodels_data.temp_<[model_name]>.filewrites].is_empty||true>
    # Final clear of temp data
    - flag server dmodels_data.temp_<[model_name]>:!

dmodels_multiwaitable_filewrite:
    type: task
    debug: false
    definitions: key|path|data
    script:
    - flag server dmodels_data.temp_<[key]>.filewrites.<[path].escaped>
    - ~filewrite path:<[path]> data:<[data]>
    - flag server dmodels_data.temp_<[key]>.filewrites.<[path].escaped>:!

dmodels_facefix:
    type: procedure
    debug: false
    definitions: facedata|resolution
    script:
    - define uv <[facedata.uv]>
    - define out.texture #<[facedata.texture]>
    - define mul_x <element[16].div[<[resolution.width]>]>
    - define mul_y <element[16].div[<[resolution.height]>]>
    - define out.uv <list[<[uv].get[1].mul[<[mul_x]>]>|<[uv].get[2].mul[<[mul_y]>]>|<[uv].get[3].mul[<[mul_x]>]>|<[uv].get[4].mul[<[mul_y]>]>]>
    - determine <[out]>

dmodels_loader_addchild:
    type: task
    debug: false
    definitions: model_name|parent|child
    script:
    - if <[child].matches_character_set[abcdef0123456789-]>:
        - define elementflag dmodels_data.temp_<[model_name]>.raw_elements.<[child]>
        - define element <server.flag[<[elementflag]>]||null>
        - if <[element]> == null:
            - stop
        - define valid_rots 0|22.5|45|-22.5|-45
        - define rot <location[<[element.rotation]>]>
        - define xz <[rot].x.equals[0].if_true[0].if_false[1]>
        - define yz <[rot].y.equals[0].if_true[0].if_false[1]>
        - define zz <[rot].z.equals[0].if_true[0].if_false[1]>
        - define count <[xz].add[<[yz]>].add[<[zz]>]>
        - if <[rot].x> in <[valid_rots]> && <[rot].y> in <[valid_rots]> && <[rot].z> in <[valid_rots]> && <[count]> < 2:
            - flag server dmodels_data.temp_<[model_name]>.raw_outlines.<[parent.uuid]>.children:->:<[child]>
        - else:
            - definemap new_outline name:<[parent.name]>_auto_<[element.name]> origin:<[element.origin]> rotation:<[element.rotation]> uuid:<util.random_uuid> parent:<[parent.uuid]> children:<list[<[child]>]>
            - flag server dmodels_data.temp_<[model_name]>.raw_outlines.<[new_outline.uuid]>:<[new_outline]>
            - flag server <[elementflag]>.rotation:0,0,0
            - flag server <[elementflag]>.origin:0,0,0
    - else:
        - define child.parent:<[parent.uuid]>
        - run dmodels_loader_readoutline def.model_name:<[model_name]> def.outline:<[child]>

dmodels_loader_readoutline:
    type: task
    debug: false
    definitions: model_name|outline
    script:
    - definemap new_outline name:<[outline.name]> uuid:<[outline.uuid]> origin:<[outline.origin].separated_by[,]||0,0,0> rotation:<[outline.rotation].separated_by[,]||0,0,0> parent:<[outline.parent]||none>
    - define flagname dmodels_data.model_<[model_name]>.namecounter_outline.<[outline.name]>
    - flag server <[flagname]>:++
    - if <server.flag[<[flagname]>]> > 1:
        - define new_outline.name <[new_outline.name]><server.flag[<[flagname]>]>
    - define raw_children <[outline.children]||<list>>
    - define outline.children:!
    - flag server dmodels_data.temp_<[model_name]>.raw_outlines.<[new_outline.uuid]>:<[new_outline]>
    - foreach <[raw_children]> as:child:
        - run dmodels_loader_addchild def.model_name:<[model_name]> def.parent:<[outline]> def.child:<[child]>
