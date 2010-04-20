#!/bin/bash

JS=public/javascripts

echo "" > $JS/application.js

for i in prototype effects controls common cookie comment favorite forum notes pool post post_mode_menu related_tags dmail user_record ; do
    cat $JS/$i.js >> $JS/application.js
done
