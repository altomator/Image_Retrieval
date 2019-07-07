# -*- coding: utf-8 -*-

# python3 label_image.py > results-img.csv

import tensorflow as tf, sys
import glob, os

############# Script pour l'évaluation du modèle #############

if __name__ == '__main__':

    # Liste des images à reconnaître (utiliser splitTrain_Validation.py pour générer le répèrtoire d'évaluation)
    #imageList = glob.glob(r"./imInput/OUT_img/*.jpg")
    imageList = glob.glob(r"./imInput/bnfDataset.encyclo2_test/*/*.jpg")

    # Répertoire contenant les données d'apprentissage (modèle)
    modelDir = r"./bnfDataset_model_encyclo2"

    # ----------------------------------------

    #print(" model: %s" % modelDir)

    # Loads label file, strips off carriage return
    label_lines = [line.rstrip() for line in tf.gfile.GFile(modelDir + r"/output_labels.txt")]

    # Unpersists graph from file
    with tf.gfile.FastGFile(modelDir + r"/output_graph.pb", 'rb') as f:
        graph_def = tf.GraphDef()
        graph_def.ParseFromString(f.read())
        _ = tf.import_graph_def(graph_def, name='')

    with tf.Session() as sess:
        # Feed the image_data as input to the graph and get first prediction
        softmax_tensor = sess.graph.get_tensor_by_name('final_result:0')

        print( "\t".join(label_lines) + "\t%s\t%s\t%s\t%s" % ("foundClass", "realClass", "success", "imgTest"))
        for image_path in imageList:

            realClass = os.path.basename(os.path.dirname(image_path))

            # Read in the image_data
            try:
                image_data = tf.gfile.FastGFile(image_path, 'rb').read()
                predictions = sess.run(softmax_tensor, {'DecodeJpeg/contents:0': image_data})
            except:
                print ("Unexpected error: %s" % sys.exc_info()[0])
                print ("--> file : %s" % image_path)
                continue


            predList = predictions[0].tolist()
            foundClass = label_lines[predList.index(max(predList))]

            print("\t".join(["%0.2f" % e for e in predList]) + "\t%s\t%s\t%d\t%s" % (foundClass, realClass, (foundClass == realClass), image_path) )
