# Run this as python.exe gen_track_car_list.py > output.yaml
import os
import json
import shutil
# Change this to your specific path
# Probably something like "C:\\Program Files (x86)\\Steam\\steamapps\\common\\assettocorsa"
ac_path = "D:\\Steam\\steamapps\\common\\assettocorsa"

tracks_path = ac_path + "\\content\\tracks"
cars_path = ac_path + "\\content\\cars"

# Thumbnails
if not os.path.isdir("public\\tracks"):
	os.mkdir("public\\tracks")
if not os.path.isdir("public\\cars"):
	os.mkdir("public\\cars")

# Listing tracks
track_folder_list = os.listdir(tracks_path)
track_list = []
track_names = {}
for track in track_folder_list:
	if os.path.isdir(tracks_path+"\\"+track) and os.path.isfile(tracks_path+"\\"+track+"\\"+track+'.kn5'):
		if os.path.isfile(tracks_path+"\\"+track+"\\ui\\outline.png") and os.path.isfile(tracks_path+"\\"+track+"\\ui\\preview.png") and os.path.isfile(tracks_path+"\\"+track+"\\ui\\ui_track.json"):
			track_list.append(track)
			# Add track name to track_details
			json_data = json.load(open(tracks_path+"\\"+track+"\\ui\\ui_track.json"))
			track_names[track] = json_data["name"]
			shutil.copyfile(tracks_path+"\\"+track+"\\ui\\outline.png","public\\tracks\\"+track+"_outline.png")
			shutil.copyfile(tracks_path+"\\"+track+"\\ui\\preview.png","public\\tracks\\"+track+"_preview.png")
		else:
			subfolder_list = os.listdir(tracks_path+"\\"+track+"\\ui")
			for subtrack in subfolder_list:
				if os.path.isfile(tracks_path+"\\"+track+"\\ui\\"+subtrack+"\\ui_track.json") and os.path.isfile(tracks_path+"\\"+track+"\\ui\\"+subtrack+"\\outline.png") and os.path.isfile(tracks_path+"\\"+track+"\\ui\\"+subtrack+"\\preview.png"):
					track_list.append(track+" "+subtrack)
					#print(track+" "+subtrack)
					json_data = json.loads(open(tracks_path+"\\"+track+"\\ui\\"+subtrack+"\\ui_track.json").read(), encoding="latin-1")
					track_names[track+" "+subtrack] = json_data["name"]
					shutil.copyfile(tracks_path+"\\"+track+"\\ui\\"+subtrack+"\\outline.png","public\\tracks\\"+track+" "+subtrack+"_outline.png")
					shutil.copyfile(tracks_path+"\\"+track+"\\ui\\"+subtrack+"\\preview.png","public\\tracks\\"+track+" "+subtrack+"_preview.png")
# Listing cars + skins
car_folder_list = os.listdir(cars_path)
car_list = []
car_skin_list = {}
car_names = {}
for car in car_folder_list:
	if os.path.isdir(cars_path+"\\"+car) and os.path.isdir(cars_path+"\\"+car+"\\skins") and os.path.isfile(cars_path+"\\"+car+"\\ui\\ui_car.json"):
		car_list.append(car)
		car_skin_list[car] = []
		try:
			json_data = json.JSONDecoder(strict=False).decode(open(cars_path+"\\"+car+"\\ui\\ui_car.json").read())
		except ValueError:
			json_data = {}
			json_data["name"] = car
		car_names[car] = json_data["name"]
		copied_skin = False
		for skin in os.listdir(cars_path+"\\"+car+"\\skins"):
			if os.path.isdir(cars_path+"\\"+car+"\\skins\\"+skin) and os.path.isfile(cars_path+"\\"+car+"\\skins\\"+skin+"\\ui_skin.json"):
				car_skin_list[car].append(skin)
				if not copied_skin and os.path.isfile(cars_path+"\\"+car+"\\skins\\"+skin+"\\preview.jpg"):
					shutil.copyfile(cars_path+"\\"+car+"\\skins\\"+skin+"\\preview.jpg","public\\cars\\"+car+".jpg")
print("# Add this to acsl.yaml")
print(":tracks: " + (','.join(track_list)))
print(":cars: " + (' '.join(car_list)))
print("# Save this as skins.yaml")
print("---")
for car in car_skin_list.keys():
	print(car + ": " + (' '.join(car_skin_list[car])))
print("# Save this as cars.yaml")
print("---")
for car in car_names.keys():
	print(car + ": " + car_names[car])
print("# Save this as tracks.yaml")
print("---")
for track in track_names.keys():
	print(track + ": " + track_names[track])