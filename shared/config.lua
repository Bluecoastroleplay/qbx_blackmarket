Config = {}

Config.Debug = false

Config.Ped = {
    model      = 's_m_y_dealer_01',
    coords     = vector4(562.72, -3124.45, 17.77, 0.33),
    freeze     = true,
    invincible = true,
    scenario   = nil,
}

Config.Target = {
    label    = 'Open Black Market',
    icon     = 'fas fa-skull-crossbones',
    distance = 2.0,
}

Config.Shop = {
    id    = 'blackmarket_dealer_01',
    label = 'Black Market',
    items = {
        { name = 'WEAPON_PISTOL',     price = 4500 },
        { name = 'ammo-9',            price =  120 },
        { name = 'lockpick',          price =  850 },
        { name = 'radio',             price =  600 },
        { name = 'bandage',           price =  200 },
        { name = 'advancedlockpick',  price = 2500 },
        { name = 'thermite',          price = 5000 },
        { name = 'crack_baggy',       price = 1200 },
        { name = 'usb_device',        price = 3000 },
        { name = 'cocaine_baggy',     price =  800 },
        { name = 'meth',              price =  600 },
    },
}