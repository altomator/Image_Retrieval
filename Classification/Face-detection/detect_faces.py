# USAGE
# python detect_faces.py --prototxt deploy.prototxt.txt --model res10_300x300_ssd_iter_140000.caffemodel --dir folder

# Adapted from www.pyimagesearch.com
# The Caffe-based face detector can be found in the face_detector sub-directory of the dnn samples:
# https://github.com/opencv/opencv/tree/master/samples/dnn/face_detector

import numpy as np
import argparse
import os
import cv2
from imutils import paths

# output folder for the CSV files
output = "OUT_csv"
nbFaces = 0

def process_image(file):
	# load the input image and construct an input blob for the image
	# by resizing to a fixed 300x300 pixels and then normalizing it
	image = cv2.imread(file)
	(h, w) = image.shape[:2]
	blob = cv2.dnn.blobFromImage(cv2.resize(image, (300, 300)), 1.0,(300, 300), (104.0, 177.0, 123.0))
	outText=""

	global nbFaces
	# pass the blob through the network and obtain the detections and predictions
	net.setInput(blob)
	detections = net.forward()

	# loop over the detections
	for i in range(0, detections.shape[2]):
			# extract the confidence (i.e., probability) associated with the prediction
			confidence = detections[0, 0, i, 2]
			# filter out weak detections by ensuring the `confidence` is greater than the minimum confidence
			if (confidence > args["confidence"]):
				# compute the (x, y)-coordinates of the bounding box for the object
				box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
				(startX, startY, endX, endY) = box.astype("int")
				if ((endX>w) or (endY>h)):
					print (" out of image : %d %d") % (w,h)
				else:
					nbFaces += 1
					text = "{:.2f}%".format(confidence * 100)
					print "\t%s" % text
					print (startX, startY,(endX-startX),(endY-startY))
					# draw the boxes
					#cv2.rectangle(image, (startX, startY), (endX, endY),(0, 0, 255), 2)
					#cv2.putText(image, text, (startX, y),cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 255), 2)
					# build the data
					if (outText ==""):
						outText = "face,%d,%d,%d,%d,%.2f" % (startX, startY,(endX-startX), (endY-startY), confidence)
					else:
						outText = "%s face,%d,%d,%d,%d,%.2f" % (outText, startX, startY,(endX-startX), (endY-startY),confidence)

	if outText != "":
		# open output file
		filename = os.path.splitext(os.path.basename(file))[0]
		outPath = os.path.join(output_dir, "%s.csv" % filename)
		outFile = open(outPath,"w")
		print >> outFile, "%s\t%s" % (filename,outText)
		outFile.close()

	else:
		print "\tno detection"
		# show the output image
		#cv2.imshow("Output", image)
		#cv2.waitKey(0)

# construct the argument parse and parse the arguments
ap = argparse.ArgumentParser()
ap.add_argument("-i", "--dir", required=True,
	help="path to input image folder")
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

# load our serialized model from disk
print(" loading model...")
net = cv2.dnn.readNetFromCaffe(args["prototxt"], args["model"])
# load the images list
filePaths = list(paths.list_images(args["dir"]))
filePaths = [img.replace("\\", "") for img in filePaths]

for i in filePaths:
	print " analysing %s" % i
	process_image(i)

print " ### faces: %d ###" % nbFaces
print " ### images analysed: %d ###" % len(filePaths)
