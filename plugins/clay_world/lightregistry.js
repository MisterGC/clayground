// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Every Light2d registers here and every LightLayer2d reads from here. A
// library script is one instance per engine, so a light declared anywhere -
// inside a PhysicsItem, in the room, beside the layer - is found without the
// layer walking the item tree or the light having to know its layer.
var lights = [];

function add(light) {
    if (lights.indexOf(light) < 0)
        lights.push(light);
}

function remove(light) {
    var i = lights.indexOf(light);
    if (i >= 0)
        lights.splice(i, 1);
}
