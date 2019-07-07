# USAGE
# python3 yolo.py --dir images --yolo yolo-coco

# adapted from https://www.pyimagesearch.com/2018/11/12/yolo-object-detection-with-opencv/

import numpy as np
import argparse
import time
import cv2
import os
from imutils import paths

# folder for the CVS files
output = "OUT_csv"
nbObject = 0

# construct the argument parse and parse the arguments
ap = argparse.ArgumentParser()
ap.add_argument("-i", "--dir", required=True,
	help="path to input folder")
ap.add_argument("-y", "--yolo", required=True,
	help="base path to YOLO directory")
ap.add_argument("-c", "--confidence", type=float, default=0.25,
	help="minimum probability to filter weak detections")
ap.add_argument("-t", "--threshold", type=float, default=0.3,
	help="threshold when applying non-maxima suppression")
args = vars(ap.parse_args())

output_dir = os.path.realpath(output)
if not os.path.isdir(output_dir):
	ap.error("Output directory %s does not exist" % output)
else:
	print ("Output will be saved to %s" % output_dir)

# load the COCO class labels our YOLO model was trained on
labelsPath = os.path.sep.join([args["yolo"], "coco.names"])
LABELS = open(labelsPath).read().strip().split("\n")

# initialize a list of colors to represent each possible class label
#np.random.seed(42)
#COLORS = np.random.randint(0, 255, size=(len(LABELS), 3), dtype="uint8")

# derive the paths to the YOLO weights and model configuration
weightsPath = os.path.sep.join([args["yolo"], "yolov3.weights"])
configPath = os.path.sep.join([args["yolo"], "yolov3.cfg"])

# load our YOLO object detector trained on COCO dataset (80 classes)
print("[INFO] loading YOLO from disk...")
net = cv2.dnn.readNetFromDarknet(configPath, weightsPath)

def process_image(file, outPath):
	# load our input image and grab its spatial dimensions
	try:
		image = cv2.imread(file)
		(H, W) = image.shape[:2]
	except ValueError:
		print("Unexpected error:", sys.exc_info()[0])
		return

	global nbObject
	outText=""

	# determine only the *output* layer names that we need from YOLO
	ln = net.getLayerNames()
	ln = [ln[i[0] - 1] for i in net.getUnconnectedOutLayers()]

	# construct a blob from the input image and then perform a forward
	# pass of the YOLO object detector, giving us our bounding boxes and
	# associated probabilities
	blob = cv2.dnn.blobFromImage(image, 1 / 255.0, (416, 416),swapRB=True, crop=False)
	net.setInput(blob)
	start = time.time()
	layerOutputs = net.forward(ln)
	end = time.time()

	# show timing information on YOLO
	#print(" YOLO took {:.6f} seconds".format(end - start))

	# initialize our lists of detected bounding boxes, confidences, and
	# class IDs, respectively
	boxes = []
	confidences = []
	classIDs = []

	# loop over each of the layer outputs
	for output in layerOutputs:
		# loop over each of the detections
		for detection in output:
			# extract the class ID and confidence (i.e., probability) of
			# the current object detection
			scores = detection[5:]
			classID = np.argmax(scores)
			confidence = scores[classID]

			# filter out weak predictions by ensuring the detected
			# probability is greater than the minimum probability
			if confidence > args["confidence"]:
				# scale the bounding box coordinates back relative to the
				# size of the image, keeping in mind that YOLO actually
				# returns the center (x, y)-coordinates of the bounding
				# box followed by the boxes' width and height
				box = detection[0:4] * np.array([W, H, W, H])
				(centerX, centerY, width, height) = box.astype("int")

				# use the center (x, y)-coordinates to derive the top and
				# and left corner of the bounding box
				x = int(centerX - (width / 2))
				y = int(centerY - (height / 2))

				# update our list of bounding box coordinates, confidences,
				# and class IDs
				boxes.append([x, y, int(width), int(height)])
				confidences.append(float(confidence))
				classIDs.append(classID)

	# apply non-maxima suppression to suppress weak, overlapping bounding boxes
	idxs = cv2.dnn.NMSBoxes(boxes, confidences, args["confidence"],args["threshold"])

	# ensure at least one detection exists
	if len(idxs) > 0:
		# loop over the indexes we are keeping
		for i in idxs.flatten():
			nbObject += 1
			# extract the bounding box coordinates
			(x, y) = (boxes[i][0], boxes[i][1])
			(w, h) = (boxes[i][2], boxes[i][3])

			# build the CSV data
			if (outText ==""):
				outText = "%s,%d,%d,%d,%d,%.2f" % (LABELS[classIDs[i]], x, y, w, h, confidences[i])
			else:
				outText = "%s %s,%d,%d,%d,%d,%.2f" % (outText, LABELS[classIDs[i]], x, y, w, h, confidences[i])
			# draw a bounding box rectangle and label on the image
			#color = [int(c) for c in COLORS[classIDs[i]]]
			#cv2.rectangle(image, (x, y), (x + w, y + h), color, 2)
			text = "{}: {:.4f}".format(LABELS[classIDs[i]], confidences[i])
			#cv2.putText(image, text, (x, y - 5), cv2.FONT_HERSHEY_SIMPLEX,0.5, color, 2)
			#imS = cv2.resize(image, None,fx=0.3, fy=0.3, interpolation = cv2.INTER_CUBIC)
			# show the output image
			#cv2.imshow("Image", imS)
			#cv2.waitKey(0)
			print (text)

		if outText != "":
			# open output file
			outFile = open(outPath,"w")
			print ("%s\t%s" % (filename, outText), file=outFile) # separator = tab
			outFile.close()

# build the images files list
filePaths = list(paths.list_images(args["dir"]))
filePaths = [img.replace("\\", "") for img in filePaths]

for i in filePaths:
	print ("...analysing %s" % i)
	filename = os.path.splitext(os.path.basename(i))[0]
	outPath = os.path.join(output_dir, "%s.csv" % filename)
	# don't reprocess an existing result
	if  os.path.isfile(outPath):
		print(" data file for %s already exists" % filename)
	else:
		try:
			process_image(i,outPath)
		except AttributeError as exc:
			print("Unexpected error:", exc)

print ("\n ### objects detected: %d ###" % nbObject)
print (" ### images analysed: %d ###" % len(filePaths))
