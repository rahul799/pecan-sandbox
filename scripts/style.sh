 #! /bin/bash

echo '${{ steps.file_changes.outputs.files_modified}}' > names.txt
cat names.txt | tr -d '[]' > new.txt
text=$(cat new.txt)
IFS=',' read -ra ids <<< "$text"
for i in "${ids[@]}"; do if [[ "$i" == *.R\" || "$i" == *.Rmd\" ]]; then echo "$i" >> new2.txt; fi; done
