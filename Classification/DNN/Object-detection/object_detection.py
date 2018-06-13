# USAGE
# python deep_learning_object_detection.py  \
#	--prototxt MobileNetSSD_deploy.prototxt.txt --model MobileNetSSD_deploy.caffemodel --dir folder

# import the necessary packages
import numpy as np
import argparse
import cv2
import os
from imutils import paths

# output folder
output = "OUT_csv"
nbObject = 0

# load the input image and construct an input blob for the image
# by resizing to a fixed 300x300 pixels and then normalizing it
# (note: normalization is done via the authors of the MobileNet SSD
# implementation)
def process_image(file):
	image = cv2.imread(file)
	(h, w) = image.shape[:2]
	blob = cv2.dnn.blobFromImage(cv2.resize(image, (300, 300)), 0.007843, (300, 300), 127.5)
	outText=""

	global nbObject

	# pass the blob through the network and obtain the detections and predictions
	#print("[INFO] computing object detections...")
	net.setInput(blob)
	detections = net.forward()

	# loop over the detections
	for i in np.arange(0, detections.shape[2]):
		# extract the confidence (i.e., probability) associated with the prediction
		confidence = detections[0, 0, i, 2]

		# filter out weak detections by ensuring the `confidence` is
		# greater than the minimum confidence
		if confidence > args["confidence"]:
			# extract the index of the class label from the `detections`,
			# then compute the (x, y)-coordinates of the bounding box for the object
			idx = int(detections[0, 0, i, 1])
			box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
			(startX, startY, endX, endY) = box.astype("int")
			if ((endX>w) or (endY>h)):
				print (" out of image : %d %d") % (w,h)
			else:
				nbObject += 1
				# display the prediction
				label = "{}: {:.2f}%".format(CLASSES[idx], confidence * 100)
				print("[INFO] {}".format(label))
				#cv2.rectangle(image, (startX, startY), (endX, endY),COLORS[idx], 2)
				#y = startY - 15 if startY - 15 > 15 else startY + 15
				#cv2.putText(image, label, (startX, y),cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS[idx], 2)
				if (outText ==""):
					outText = "%s,%d,%d,%d,%d,%.2f" % (CLASSES[idx], startX, startY,(endX-startX), (endY-startY), confidence)
				else:
					outText = "%s %s,%d,%d,%d,%d,%.2f" % (outText, CLASSES[idx],startX, startY,(endX-startX), (endY-startY),confidence)

	if outText != "":
		# open output file
		filename = os.path.splitext(os.path.basename(file))[0]
		outPath = os.path.join(output_dir, "%s.csv" % filename)
		outFile = open(outPath,"w")
		print >> outFile, "%s\t%s" % (filename,outText)
		outFile.close()
	else:
		print "\tno detection"

# construct the argument parse and parse the arguments
ap = argparse.ArgumentParser()
ap.add_argument("-i", "--dir", required=True,
	help="path to input folder")
ap.add_argument("-p", "--prototxt", required=True,
	help="path to Caffe 'deploy' prototxt file")
ap.add_argument("-m", "--model", required=True,
	help="path to Caffe pre-trained model")
ap.add_argument("-c", "--confidence", type=float, default=0.1,
	help="minimum probability to filter weak detections")
args = vars(ap.parse_args())

output_dir = os.path.realpath(output)
if not os.path.isdir(output_dir):
	ap.error("Output directory %s does not exist" % output)
else:
	print "Output will be saved to %s" % output_dir

# initialize the list of class labels MobileNet SSD was trained to
# detect, then generate a set of bounding box colors for each class
CLASSES = ["background", "aeroplane", "bicycle", "bird", "boat",
	"bottle", "bus", "car", "cat", "chair", "cow", "diningtable",
	"dog", "horse", "motorbike", "person", "pottedplant", "sheep",
	"sofa", "train", "tvmonitor"]
#COLORS = np.random.uniform(0, 255, size=(len(CLASSES), 3))

# load our serialized model from disk
print("[INFO] loading model...")
net = cv2.dnn.readNetFromCaffe(args["prototxt"], args["model"])

filePaths = list(paths.list_images(args["dir"]))
filePaths = [img.replace("\\", "") for img in filePaths]

for i in filePaths:
	print " analyse de %s" % i
	process_image(i)

print "\n ### objects detected: %d ###" % nbObject
print " ### images analysed: %d ###" % len(filePaths)

# show the output image
#cv2.imshow("Output", image)
#cv2.waitKey(0)
