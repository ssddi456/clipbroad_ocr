# -*- coding: UTF-8 -*-

from aip import AipOcr
import json
import sys
import os
import pyperclip

filepath = ''
if len(sys.argv) >= 2:
    filepath = sys.argv[1]
else:
    exit()


def get_file_content(filePath):
    with open(filePath, 'rb') as fp:
        return fp.read()


APP_ID = "17725084"
API_KEY = "Lu5bl3v5u3Vi2rzXQNBg1HG8"
SECRET_KEY = "59ndiUv8jaIPLIre9lBOxdHFLtMOUonN"

client = AipOcr(APP_ID, API_KEY, SECRET_KEY)

image = get_file_content(filepath)

""" 调用通用文字识别, 图片参数为本地图片 """
try:
    ret = client.basicGeneral(image)
    pyperclip.copy('\n'.join([x['words'] for x in ret['words_result']]))
finally:
    try:
        os.remove(filepath)
    finally:
        pass

