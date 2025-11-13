return function(array, key, match): {} | nil 
	for k,v in ipairs(array) do 
		print("pet name : ", v[key]) 
		if v[key] == match then 
			return v 
		end 
	end 
end
