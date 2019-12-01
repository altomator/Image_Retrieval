# -*- coding: utf-8 -*-
#!/usr/bin/python

# use case: extract metadata from the TNA catalog
# input is a serie list number (see below)
# output is a XML like data file (not a real XML)

import requests;      #version 2.18.4, used for connecting to the API
import sys
from time import sleep
from math import log
import os
import locale;
os.environ["PYTHONIOENCODING"] = "utf-8";
myLocale=locale.setlocale(category=locale.LC_ALL, locale="en_GB.UTF-8");

#print(myText.encode('utf-8', errors='ignore'))

#series_list = [[x,1] for x in ['C426','C392','C394','C416','C415','C350','C428','C374','C422','C152']]
#series_list = [[x,0] for x in ['A13530113']] #Richmond
#series_list = [[x,0] for x in ['A13532926']] #Gloucestershire
#series_list = [[x,0] for x in ['A13531661','A13531878']] #East and West Sussex
#series_list = [[x,0] for x in ['A13530781','A13531184','A13532436']] #Cornwall, Devon, Dorset
#series_list = [[x,0] for x in ['A13532757','A13531853','A13532331','A13530620']] #Kent, Somerset, Worcestershire
#series_list = [[x,0] for x in ['A13531317']] #Cumbria
#series_list = [[x,0] for x in ['A13530620']] #Northumberland
#series_list = [[x,0] for x in ['A13531418']] #Surrey

#series_list = [[x,0] for x in ['C3085']] #TNA Designs BT 42
#series_list = [[x,0] for x in ['C3086']] #TNA Designs BT 43
#series_list = [[x,0] for x in ['C439493']] #TNA Designs BT43-348-394008
#series_list = [[x,0] for x in ['C25263']] #TNA Designs BT43/412/216416
#series_list = [[x,0] for x in ['C25261']] #TNA Designs BT43/356
#series_list = [[x,0] for x in ['C439519']] #TNA Designs BT43/373
#series_list = [[x,0] for x in ['C439525']] #TNA Designs BT43/379
#series_list = [[x,0] for x in ['C439508']] #TNA Designs BT43/363
#series_list = [[x,0] for x in ['C439446']] #TNA Designs BT43/300
##series_list = [[x,0] for x in ['C439473']] #TNA Designs BT43/328
#series_list = [[x,0] for x in ['C439491']] #TNA Designs BT43/346
series_list = [[x,0] for x in ['C439493']] #TNA Designs BT43/348

#series_list = [[x,0] for x in ['C440606']] #TNA Designs BT52/143
#series_list = [[x,0] for x in ['C440606']]
#series_list = [[x,0] for x in ['C439598']] #TNA Designs BT50/20



# https://discovery.nationalarchives.gov.uk/browse/r/h/C3085
#series_list = [[x,0] for x in ['C3093']] #TNA Designs BT 50/1

#series_list = [[x,0] for x in ['C11678861']] #TNA Designs BT 50/1
#series_list = [[x,0] for x in ['C439589']] #TNA Designs BT 50/11
#series_list = [[x,1] for x in ['C96','C246','C43','C4']] #TNA
#series_list = [[x,1] for x in ['C256','C148','C18','C64']] #TNA

target_dir = "CATALOGUE/"
if not os.path.isdir(target_dir):
    os.mkdir(target_dir)

max_level = 3

#series_list = ["A13530124", 0]
#myfile = open("stac_dates.txt","w")
#myfile.close()
PAGE_LIMIT = 200
TOTAL_LIMIT = 10000

#    myfile = open(series.replace(" ","_") + ".children.txt","w")
#        myfile.write("|".join([str(X) for X in [rj["id"],rj["coveringDates"],rj["coveringFromDate"],rj["coveringToDate"],rj["recordOpeningDate"], \
#                               str(rj["scopeContent"]["description"]).replace("\n"," ").replace("  ", " ").replace("|","~"),rj["closureType"], \
#                               rj["citableReference"], str(rj["isParent"]),"\n"]]))
field_list = ["id","coveringDates","coveringFromDate","coveringToDate","recordOpeningDate",["scopeContent","description"],"closureType","citableReference","isParent"]
#    myfile.close()

# weird code for unicode export
def stuff2String(myStuff):
    if isinstance(myStuff,(int, long)):
        out = str(myStuff).encode('utf-8')
    elif myStuff==None:
        out = "None"
    else:
        out = (myStuff).encode('utf-8')
    return out


def get_series_children(series, field_list, page_limit=100, total_limit=1000):

    print("SERIES:",series)
    myparams={"limit":page_limit, "batchStartMark":"*"}
    headers={"Accept": "application/json"}; #we want the API to return data in JSON format
    url="https://discovery.nationalarchives.gov.uk/API/records/children/" + series
    s=requests.Session(); #creating a session just groups the set of requests together
    r=s.get(url, headers=headers, params=myparams); #send the url with our added parameters, call the response "r"
    r.raise_for_status(); #This checks that we received an http status 200 for the server response
    #so we know nothing's gone wrong with the call (if something has gone wrong we'd get a 404 or 500 error for example)
    rjson=r.json()
    retrieved = 0

    out_children = []

    for rj in rjson["assets"]:
        out_fields = []
        for f in field_list:
            if isinstance(f,str):
                field_value = rj[f]
            elif isinstance(f,list):
                field_value = rj[f[0]][f[1]] # if fields are more nested then this should be recursive but for now it is only for the scope content description
            out_fields.append(stuff2String(field_value).replace("\n"," ").replace("\r"," ").replace("  "," ").replace("|","~"))
        retrieved += 1
        out_children.append(out_fields)
        last_id = rj["sortKey"]
    print("Total records retrieved:", retrieved)

    print("More:",rjson["hasMoreAfterLast"])
    while (rjson["hasMoreAfterLast"] and retrieved < total_limit):
        sleep(4)
        ## Update the parameter set with the returned value for nextBatchMark so we can get the next portion of data with our next request

        myparams["batchStartMark"] = last_id

        ## Make our next GET request

        print("********Params:",myparams,"*************")
        r=s.get(url, headers=headers, params=myparams);
        rjson = r.json()
        for rj in rjson["assets"]:
            out_fields = []
            for f in field_list:
                if isinstance(f,str):
                    field_value = rj[f]
                elif isinstance(f,list):
                    field_value = rj[f[0]][f[1]] # if fields are more nested then this should be recursive but for now it is only for the scope content description
                out_fields.append(stuff2String(field_value).replace("\n"," ").replace("  "," ").replace("|","~"))
            out_children.append(out_fields)
            retrieved += 1
            last_id = rj["sortKey"]
        print("Total records retrieved:", retrieved)
    print("Total records retrieved:", retrieved)

    return(out_children)


while len(series_list) > 0:
    series = series_list[0]
    parent = series[0]
    level = series[1]
    series_list = series_list[1:]
    out_file = open(target_dir + parent + "_level_" + str(level) + ".txt", "w")
    children = get_series_children(parent,field_list,PAGE_LIMIT,TOTAL_LIMIT)

    for child in children:
        out_file.write("<parent>" + parent + "</parent>")
        for idx, x in enumerate(child):
                element = str(field_list[idx])
                if element == "['scopeContent', 'description']":
                        x=str(x).replace(r'<p>','')
                        x=str(x).replace(r'</p>','--')
                        x=str(x).replace(r'<scopecontent>','')
                        x=str(x).replace(r'</scopecontent>','')
                        out_file.write("<description>"+ x +"</description>")
                else:
                        out_file.write("<"+str(field_list[idx])+">"+ x +"</"+str(field_list[idx])+">")
        #out_file.write("|".join([parent] + [str(x).replace(r'\r',' ') for x in child]))
        out_file.write("\n")
        if child[-1] == "True":
            if level+1 <= max_level:
                series_list.append([child[0],level+1])
    out_file.close()


#series_file = open("second_level_series.txt","r")
#out_file = open("third_level_series.txt","w")
#for row in series_file:
#    parent = row.split("|")[1]
#    top_children = get_series_children(parent,field_list,500,25000)
#    print("Top level:",len(top_children))
#    for top in top_children:
#        #print(top)
#        out_file.write("|".join([parent] + [str(x).replace(r'\r',' ') for x in top]))
#        out_file.write("\n")
#        #second_level = get_series_children(top[0],field_list,100,1000)
        #for sl in second_level:
            #out_file.write("|".join(top))
        #    out_file.write("|".join([top[0]]+[str(x) for x in sl]))
        #    out_file.write("\n")

#out_file.close()
