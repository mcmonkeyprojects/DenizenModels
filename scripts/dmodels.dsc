
model_part_stand:
    type: entity
    debug: false
    entity_type: armor_stand
    mechanisms:
        marker: true
        gravity: false
        visible: false
        custom_name_visible: true
        custom_name: part

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
    - yaml unload id:<[yamlid]>
    - foreach <[parts]> key:id as:part:
        - if <[part.empty]||false>:
            - foreach next
        - define rots <[part.rotation].split[,].parse[to_radians]>
        # Idk wtf is with the scale here. It's somewhere in the range of 25 to 26. 25.45 seems closest in one of my tests,
        # but I think that's minecraft packet location imprecision at fault so it's probably just 26.
        - define offset <location[<[part.origin]>].div[26].rotate_around_y[<util.pi>]>
        - define pose [head=<[rots].get[1].mul[-1]>,<[rots].get[2].mul[-1]>,<[rots].get[3]>]
        - spawn model_part_stand[equipment=[helmet=<[part.item]>];armor_pose=<[pose]>] <[location].add[<[offset]>]> save:spawned
