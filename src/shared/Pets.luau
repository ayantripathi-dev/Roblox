local Pets = {
	Settings = {
		MaxEquipped = 3
	},
	Eggs = {
		Basic = {
			Cost = 500,
			Pets = {
				{Name = "Dog", Rarity = "Common", Multiplier = 1.2, Weight = 70},
				{Name = "Cat", Rarity = "Uncommon", Multiplier = 1.5, Weight = 20},
				{Name = "Dragon", Rarity = "Legendary", Multiplier = 5.0, Weight = 5},
				{Name = "Unicorn", Rarity = "Mythic", Multiplier = 10.0, Weight = 1},
			}
		},
		Golden = {
			Cost = 5000,
			Pets = {
				{Name = "Gold Dog", Rarity = "Rare", Multiplier = 3.0, Weight = 60},
				{Name = "Gold Cat", Rarity = "Epic", Multiplier = 6.0, Weight = 30},
				{Name = "Phoenix", Rarity = "Legendary", Multiplier = 15.0, Weight = 9},
				{Name = "Dominus", Rarity = "Godly", Multiplier = 50.0, Weight = 1},
			}
		}
	}
}

return Pets
