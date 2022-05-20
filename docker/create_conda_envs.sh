# this script is run from Dockerfile
for file in $(ls /opt/lrvfc/envs/*)
do	
	name=$(basename "$file" .yaml)
	
	echo "Creating environment: $name"
	/opt/conda/bin/conda env create --file $file --name $name
    echo "source activate $name" >> ~/.bashrc
    PATH=/opt/lrvfc/envs/$name/bin:$PATH
done;
export PATH
