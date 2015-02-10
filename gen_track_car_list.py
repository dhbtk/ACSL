# Run this as python.exe gen_track_car_list.py > output.yaml
import os
# Change this to your specific path
# Probably something like "C:\\Program Files (x86)\\Steam\\steamapps\\common\\assettocorsa"
ac_path = "D:\\Steam\\steamapps\\common\\assettocorsa"

tracks_path = ac_path + "\\content\\tracks"
cars_path = ac_path + "\\content\\cars"

# Listing tracks
track_folder_list = os.listdir(tracks_path)
track_list = []
for track in track_folder_list:
	if os.path.isdir(tracks_path+"\\"+track) and os.path.isfile(tracks_path+"\\"+track+"\\"+track+'.kn5'):
		track_list.append(track)
# Listing cars + skins
car_folder_list = os.listdir(cars_path)
car_list = []
car_skin_list = {}
for car in car_folder_list:
	if os.path.isdir(cars_path+"\\"+car) and os.path.isdir(cars_path+"\\"+car+"\\skins"):
		car_list.append(car)
		car_skin_list[car] = []
		for skin in os.listdir(cars_path+"\\"+car+"\\skins"):
			if os.path.isdir(cars_path+"\\"+car+"\\skins\\"+skin) and os.path.isfile(cars_path+"\\"+car+"\\skins\\"+skin+"\\ui_skin.json"):
				car_skin_list[car].append(skin)
print("# Add this to acsl.yaml")
print(":tracks: " + (' '.join(track_list)))
print(":cars: " + (' '.join(car_list)))
print("# Save this as skins.yaml")
print("---")
for car in car_skin_list.keys():
	print(car + ": " + (' '.join(car_skin_list[car])))