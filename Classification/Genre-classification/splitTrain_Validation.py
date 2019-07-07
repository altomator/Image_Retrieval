# -*- coding: utf-8 -*-

# usage : python3 splitTrain_Validation.py

import glob, os, random, shutil


############# Script répartissant le jeu de données en deux parties : Apprentissage et Evaluation (effectue un copie des images) #############

if __name__ == '__main__':

    # Répartoire contenant à la base 1 dossier par catégorie. Ces dossiers contiennent
    # les images correspondantes (avec possiblement des sous-dossiers)
    datasetPath = r"./imInput/bnfDataset2.presse"

    # Répartition apprentissage/évaluation (ex: 80% pour l'apprentissage)
    ratioApprentissage = 1

    # ----------------------------------------

    print("-- debut --")
    print (" modele : %s " % datasetPath)
    trainPath = datasetPath + "_train"
    testPath = datasetPath + "_test"


    try:
        os.mkdir(trainPath)
        os.mkdir(testPath)
    except:
        print("-- erreur mkdir --")
        pass


    for catDir in glob.glob(os.path.join(datasetPath, "*")):

        cat = os.path.basename(catDir).split("-")[0]

        print("%s => %s " % (cat, catDir))

        listImg = [f for f in glob.iglob(os.path.join(catDir, r"**/*.jp*"), recursive=True)]
        listImgTrain = random.sample(listImg, int(ratioApprentissage * len(listImg)))
        listImgTest = set(listImg).difference(listImgTrain)

        print("Total %d" % len(listImg))
        print(" => Train %d" % len(listImgTrain))
        print(" => Test %d" % len(listImgTest))

        try:
            os.mkdir(os.path.join(trainPath, cat))
            os.mkdir(os.path.join(testPath, cat))
        except:
            pass

        numImg = 0
        for imgPath in listImgTrain:
            shutil.copy(imgPath, os.path.join(trainPath, cat,  "%s_%d.jpg" % (cat, numImg)) )
            numImg = numImg + 1

        for imgPath in listImgTest:
            shutil.copy(imgPath, os.path.join(testPath, cat, "%s_%d.jpg" % (cat, numImg)))
            numImg = numImg + 1
