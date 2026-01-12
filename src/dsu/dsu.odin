package dsu

Dsu :: struct {
    size: int,
    groups_key: []i32,
    groups_height: []i32,
    groups_weight: []i32,
}

new :: proc(n: int) -> (self: Dsu) {
    groups_key := make([]i32, n)
    groups_height := make([]i32, n)
    groups_weight := make([]i32, n)

    for i in 0..<n {
        groups_key[i] = i32(i)
        groups_height[i] = 1
        groups_weight[i] = 1
    }

    self = Dsu {
        size = n,
        groups_key = groups_key,
        groups_height = groups_height,
        groups_weight = groups_weight,
    }

    return
}

find :: proc(self: ^Dsu, target: i32) -> (group_key: i32) {
    if self.groups_key[target] == target {
        return target
    }

    self.groups_key[target] = find(self, self.groups_key[target])

    return self.groups_key[target]
}

join :: proc(self: ^Dsu, target_a: i32, target_b: i32) {
    key_a :=  find(self, target_a)
    key_b :=  find(self, target_b)

    if key_a == key_b {
        return 
    }

    if self.groups_height[key_a] < self.groups_height[key_b] {
        key_a, key_b = key_b, key_a
    }

    self.groups_key[key_b] = key_a
    self.groups_weight[key_a] += self.groups_weight[key_b]

    if self.groups_height[key_a] == self.groups_height[key_b] {
        self.groups_height[key_a] += 1
    }
}

key_group_weight :: proc(self: ^Dsu, target: i32) -> (weight: i32) {
    weight = self.groups_weight[find(self, target)]

    return
}

drop :: proc(self: ^Dsu) {
    delete(self.groups_key)
    delete(self.groups_height)
    delete(self.groups_weight)
}

