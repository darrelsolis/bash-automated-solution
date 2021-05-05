# Student Name: Allain Darrel Julius B. Solis
# Student Number: 10517225

#!/bin/bash
#################################### USER INTERFACE FUNCTIONS ########################################
main_menu() { # Function to input main menu
	echo -e "-------------- CSI6203 IMAGE DOWNLOADER --------------\n"
	echo -e "[1] DOWNLOAD SPECIFIC THUMBNAIL\n[2] DOWNLOAD IMAGES WITHIN A RANGE"
	echo -e "[3] DOWNLOAD ALL THUMBNAILS\n[4] CLEAN UP FILES"
	echo -e "[5] EXIT PROGRAM\n"
	read -p "Select a function from the options above: " userOption 
}
specific_thumb_view() { # Function to let the user input the specific thumbnail to download
	clear && input_dir # Asks the user to input directory name
	input_spec_thumb # Calls the function that lets the user input the specific thumbnail
	sleep 1 && echo -e "\nSpecified thumbnail found.\n" 
	specific_thumb_dl $thumbnail $dirName # Calls the function that will download the specific thumbnail
} 
img_range_view() { # Function to let the user input the starting and end range of the thumbnails to download
	clear && input_dir # Asks the user to input directory name
	input_start_thumb # Calls the function that lets the user input the starting thumbnail
	input_end_thumb # Calls the function that lets the user input the end thumbnail
	local numOfImages=$(fetch_img_num $startIndex $endIndex) # Fetches the number of images based on the given start and end index
	input_all_or_num $numOfImages # Asks the user if they want to download all or only a number of images
	if [[ $allOrNum -eq 1 ]]; then # If the user chose ALL
		img_range_dl $startIndex $endIndex "ALL" $dirName # Calls the function that will download images from a given range
	elif [[ $allOrNum -eq 2 ]]; then # If the user chose ONLY A NUMBER
		input_num_of_img $numOfImages # Asks the user to input the specific number of images to download
		img_range_dl $startIndex $endIndex $specNumImg $dirName # Calls the function that will download images from a given range
	fi
} 
all_thumb_view() { 
	clear && input_dir  # Asks the user to input directory name
	echo -e "Downloading all thumbnails from media gallery...\n" && sleep 1.5
	all_thumb_dl $dirName # Calls the function that will download all images in the specified directory
}
clean_up_view() { 
	clear && input_verify_deletion # Confirms if user really wants to delete all files 
	clean_up_files # Calls the function that will handle the user's decision on whether to delete files or not
}
exit_view() { # Displays an exit message to the user
	echo -e "\nThank you for using this program! Exiting...\n" && sleep 1.5
}
#################################### MAIN FUNCTIONS (LOGIC) ########################################
# Functions that achieve the main functionalities of the program

specific_thumb_dl() { # Function that downloads a specific thumbnail in a directory from a given URL
	# Parameters: $1 (thumbnail), $2 (directory name)
	let fileSize=0
	overwriteOrSkip=""
	# Fetches all the download URLs and filters the specific thumbnail
	local url=$(fetch_download_urls | grep $1) 
	# Fetches all the download URLs, filters the specific thumbnail and only extracts the "<filename>.jpg" part
	local imgFile=$(fetch_download_urls | grep $1 | sed "s/.*\///g") 
	# Checks if the image file in the specified directory exists
	if [[ -e "$2/$imgFile" ]]; then
		input_overwrite_or_skip $imgFile
	fi
	
	if [[ $overwriteOrSkip -eq 1 ]]; then # If user wants to overwrite the existing file
		rm $2/$imgFile # Remove the existing file
		echo -e "\nThe existing file will be replaced with a new copy.\n" && sleep 1.5
	elif [[ $overwriteOrSkip -eq 2 ]]; then # If user wants to skip the existing file
		echo -e "\nSkipping download of \"$imgFile\" image file... \n" && sleep 1
		if [[ $userOption -eq 1 ]]; then # If user chose to download a specific thumbnail only
			sleep 1.5
			echo -e "Sending you back to the main menu... " && sleep 1.5
			clear
		fi
	fi
	
	if ! [[ $overwriteOrSkip -eq 2 ]]; then 
		wget --quiet -P $2 $url # Download process of the specific image using wget
		if [[ prevCmdExitCode -eq 0 ]]; then # If the wget command ran successfully
			fileSize=$(wc -c $2/$imgFile | awk '{ printf "%.1f\n", $1/1000 }') # Assigns the file size of the downloaded file in this global variable
			echo -n "Downloading DSC0${1} with the file name ${imgFile}, with a file size of ${fileSize} KB ..."
			sleep 1.5 && echo -e " File download complete\n" && sleep 1
		else
			echo -e "Sorry, the image file \"$imgFile\" cannot be downloaded.\n"
		fi
	fi
}
all_thumb_dl() { # Function that downloads all images in a directory from a given URL
	# Parameter: $1 (Directory name)
	let local lastIndex=${#validImgList[@]}-1 # Substracts 1 from validImgList length to get the last index
	all_in_range 0 $lastIndex $1 # Calls the function that downloads all images in a given range
}
img_range_dl() {  # Function that downloads a range of images in a directory from a given URL
	# Parameters: $1 (start index), $2 (end index), $3 (number of images), $4 (directory name)
	if [[ $3 = "ALL" ]]; then # If all images are to be downloaded
		echo -e "\nAll files will be downloaded within the given start and end range.\n"
		all_in_range $1 $2 $4
	else # If only a specific number of images are to be downloaded
		randomIndexList=($(generate_rand_ind $1 $2 $3)) # Creates a global list of random index based on the given parameters
		echo -e "\n$3 file(s) will be downloaded randomly within the given start and end range.\n"
		specific_num_in_range $4 # Calls the function that downloads a specific number in a given range
	fi
}
clean_up_files() { # Function that cleans up directories recursively (all files inside are deleted)
	local files=($(ls -A | awk '{ print $1 }')) # Creates a list from the result of the listed files excluding the dot directories
	let local dirNum=0
	if [[ $proceedDel = 'Y' ]]; then # If user confirms to clean up everything
		for content in "${files[@]}"; do # Iterates in every file of the list
			if [[ -d $content ]]; then # If a directory is found,
				(( dirNum++ )) # Counter value increases
				rm -r $content # The directory along all its files are removed
			fi
		done
		if [[ $dirNum -eq 0 ]]; then # If there's no directory found
			sleep 1.5 && echo -e "\nNo files to clean up."
		elif [[ prevCmdExitCode -eq 0 ]]; then
			sleep 1.5 && echo -e "\nFile clean up success!"
			dirName="" # Sets specified directory name variable to empty
		fi		
	fi
	sleep 1 && echo -e "\nSending you back to the main menu..." && sleep 1.5
	clear
}
#################################### IMAGE RANGE FUNCTIONS ########################################
# Functions that are called when a range is needed in downloading an image

all_in_range() { # Function that downloads all images in a given start and end range
	# Parameters: $1 (start index), $2 (end index), $3 (directory name)
	local totalSize=0
	# Downloads an image from the given start index until the end index
	for (( i=$1; i<=$2; i++ )); do
		specific_thumb_dl ${validImgList[$i]} $3 # Calls the function that will download the specific thumbnail in the current iteration
		totalSize=$(calc_total_size $totalSize) # Total size gets reassigned every iteration
	done
	echo -e "Total size of file(s) downloaded: $(disp_formatted_total $totalSize)\n" # A supporting function is called to format the total size into KB or MB
}
specific_num_in_range() { # Function that only download a specific number of images in a given start and end range
	# Parameter: $1 (directory name)
	local totalSize=0
	# Downloads the images from the created random index list
	for (( i=0; i<${#randomIndexList[@]}; i++ )); do # randomIndexList (global variable from img_range_dl() function)
		local randomIndex=${randomIndexList[$i]}
		specific_thumb_dl ${validImgList[$randomIndex]} $1 # Calls the function that will download the specific thumbnail in the current iteration
		totalSize=$(calc_total_size $totalSize) # Total size gets reassigned every iteration
	done
	echo -e "Total size of file(s) downloaded: $(disp_formatted_total $totalSize)\n" # A supporting function is called to format the total size into KB or MB
}
#################################### SUPPORTING FUNCTIONS ########################################
# These functions are called in order to achieve a specific task in the secondary or main functions

parse_html() { # Function to extract only the needed information from the media gallery website
	local url="https://www.ecu.edu.au/service-centres/MACSC/gallery/gallery.php?folder=ml-2018-campus"
	local toDelete_left=".*<img src=\""
	local delimiter="\" alt=\"DSC0"
	local toDelete_right="\">"
	curl -s $url | grep "img src" | # Finds only the lines where the image source are located
	# Trims the unnecessary text and leaves only the download URL and the specific thumbnail without the DSC prefix
	sed -e "s/$toDelete_left//g; s/$delimiter/ /g; s/$toDelete_right//g" 
}
fetch_download_urls() { # Function to extract all the download URLS from the parsed HTML
	parse_html | awk '{ print $1; }'
}
fetch_valid_images() { # Function to extract all specific thumbnails without the DSC prefix
	parse_html | awk '{ print $2; }'
}
fetch_img_index() { # Function to fetch the index of the image thumbnail
	# Parameters: $1 (Image thumbnail)
	for index in "${!validImgList[@]}"; do # Iterates every image in the list of valid images
		if [[ ${validImgList[$index]} == $1 ]]; then 
			echo $index # Prints the index if it matches with the image thumbnail parameter
			break
		fi
	done
}
fetch_img_num() { # Function to fetch the number of images within the start and end index
	# Parameters: $1 (startIndex), $2 (endIndex)
	let local numOfImages=0
	for (( i=$1; i<=$2; i++ )); do 
		(( numOfImages++ )) # Variable that will count the number of images from the start to end index
	done
	echo $numOfImages
}
generate_rand_ind() { # Function to generate a list of random index based from a given range and specific number
	# Parameters: $1 (start), $2 (end), $3 (number/s to generate)
	shuf -i $1-$2 -n $3 # shuf command will be used to generate a random list using the given parameters
}
calc_total_size() { # Function to calculate total size 
	# Parameter: ($1) total size of files downloaded
	# Gets the recent value of the global variable $fileSize and adds the current totalSize to it
	echo "$fileSize $1" | awk '{ printf "%.1f\n", $1+$2 }' 
}
disp_formatted_total() { # Function to format the total size in KB (less than 1000 kb) or MB (greater than or equal to 1000 kb) 
	# Parameter: ($1) total size of files downloaded
	echo "$1" | awk '{ if ( $1 >= 1000 ) printf "%.1f MB\n", $1/1000; else printf "%.1f KB\n", $1; }'
}
#################################### VALIDATION FUNCTIONS ########################################
# These functions are called to validate the input of the user and display prompts accordingly

# Functions with a prefix input (e.g. input_function_name) will validate the user input based
# on a requirement and displays a message to the user on what is the appropriate action to proceed
input_spec_thumb() {
	thumbnail=""
	local validInput="^[0-9]+$"
	# Will continue to ask user for the filename until a valid thumbnail is specified
	until [[ $result = "Valid"  ]] && [[ $thumbnail =~ $validInput ]]; do 
		read -p "Enter the specific thumbnail you want to download: " thumbnail
		if ! [[ $thumbnail =~ $validInput ]]; then # If user specifies an invalid thumbnail (letters, punctuations, etc.)
			sleep 1
			clear && echo -e "Invalid input. Please specify a valid thumbnail.\n"
		else
			local result=$(is_image_valid $thumbnail) # Calls thumbnail validation function
			if ! [[ $result = "Valid" ]]; then
				sleep 1
				clear && echo -e "Sorry, the thumbnail you've specified cannot be found. Please try again.\n"
			fi
		fi 
	done
}
input_start_thumb() {
	startThumb="" 
	startIndex="" 
	local validInput="^[0-9]+$"
	# Will continue to ask user for the filename until a valid start thumbnail is specified
	# and the starting thumbnail is not the last thumbnail in the list
	until [[ $startResult = "Valid"  ]] && [[ $startThumb =~ $validInput ]] && [[ $startIndex -ne ${#validImgList[@]}-1 ]]; do
		read -p "Enter the filename of the starting thumbnail: " startThumb
		if ! [[ $startThumb =~ $validInput ]]; then # If user specifies an invalid thumbnail (letters, punctuations, etc.)
			sleep 1
			clear && echo -e "Invalid input. Please specify a valid thumbnail.\n"
		else
			local startResult=$(is_image_valid $startThumb) # Calls thumbnail validation function
			if ! [[ $startResult = "Valid" ]]; then
				sleep 1
				clear && echo -e "Sorry, the thumbnail you've specified cannot be found. Please try again.\n"
			else
				startIndex=$(fetch_img_index $startThumb) # Calls the function that will fetch the image index
				# If the user specifies an image that is the last one, there would be no need for an ending range
				if [[ $startIndex -eq ${#validImgList[@]}-1  ]]; then 
					sleep 1
					clear && echo -e "Sorry, the image you've specified as the starting range is the last one. Please choose another one. \n"
				fi
			fi
		fi 
	done
	sleep 1
	echo -e "\nSpecified thumbnail found.\n"
}
input_end_thumb() {
	endThumb=""
	endIndex=""
	local validInput="^[0-9]+$"
	# Will continue to ask user for the filename until a valid end thumbnail is specified
	# and the index of the end thumbnail is greater than the starting thumbnail
	until [[ $endResult = "Valid"  ]] && [[ $endThumb =~ $validInput ]] && [[ $endIndex -gt $startIndex ]]; do
		echo -e "Starting thumbnail: $startThumb\n"
		read -p "Enter the filename of the end thumbnail: " endThumb
		if ! [[ $endThumb =~ $validInput ]]; then # If user specifies an invalid thumbnail (letters, punctuations, etc.)
			sleep 1
			clear && echo -e "Invalid input. Please specify a valid thumbnail.\n"
		else
			local endResult=$(is_image_valid $endThumb) # Calls thumbnail validation function
			if ! [[ $endResult = "Valid" ]]; then
				sleep 1
				clear && echo -e "Sorry, the thumbnail you've specified cannot be found. Please try again.\n"
			else
				endIndex=$(fetch_img_index $endThumb) # Calls the function that will fetch the image index
				# Invalid range condition, e.g. Start range: 0209, End range: 0200
				if  [[ $endIndex -le $startIndex ]]; then
					sleep 1
					clear && echo -e "Invalid range given! Please try again. \n"
				fi
			fi
		fi 
	done
	sleep 1
	echo -e "\nSpecified thumbnail found.\n"
}
input_num_of_img() { # Validation of the number of images the user specifies
	# Parameter: $1 (number of images in range)
	let specNumImg=0
	local numOfImages=$(($1)) # Converts the image number parameter from a string to an integer
	local validInput="^[0-9]+$"
	echo ""
	# Will continue to ask the user of the specific number of images to download until the specified number
	# is less than or equal to the number of images within the given ranges, not equal to zero and is a valid number
	until [[ $specNumImg -le $numOfImages ]] && ! [[ $specNumImg -eq 0 ]] && [[ $specNumImg =~ $validInput ]]; do
		read -p "Enter number of images to download: " specNumImg
		if ! [[ $specNumImg -le $numOfImages ]] || [[ $specNumImg -eq 0 ]] || ! [[ $specNumImg =~ $validInput ]]; then
			clear && echo -e "Invalid input! Please enter a valid number within the $1 images. \n"
		fi 
	done
}
input_all_or_num() { # Validation of the specified option (All images or only a number) by the user 
	# Parameter: $1 (number of images in range)
	allOrNum=""
	# Different valid inputs and error message when there are only 2 images in the range
	if [[ $1 -eq 2 ]]; then
		local validInput="^1{1}$"
		local err="Invalid input! Please enter 1 to proceed:\n"
	else
		local validInput="^[1-2]{1}$"
		local err="Invalid input! Please choose from the options below (1 or 2):\n"
	fi

	until [[ $allOrNum =~ $validInput ]]; do
		echo -e "Starting and ending ranges of the $1 thumbnails have been verified successfully. Do you want to download: \n"
		# If there are only 2 images in the range, only the first option is displayed	
		if [[ $1 -eq 2 ]]; then
			echo -e "[1] All images in range\n"
		else
			echo -e "[1] All images in range\n[2] Only a specific number of images in range\n"
		fi
		read -p "Select an option to proceed: " allOrNum
		disp_error_regex "$allOrNum" "$validInput" "$err" 
	done
}
input_verify_deletion() { # Validation of the specified option (confirm delete or go back) from the user
	proceedDel=""
	local validInput="^[YN]{1}$"
	local err="Invalid input! Please choose from the options below [Y or N]:\n"
	until [[ $proceedDel =~ $validInput ]]; do
		echo -e "*WARNING* You are about to delete all created directories along all the file(s) inside it. Are you sure with this?\n"
		echo -e "[Y] I'm sure.\n[N] This was a mistake! Let me go back.\n"
		read -p "Select an option to proceed: " proceedDel
		disp_error_regex "$proceedDel" "$validInput" "$err"
	done
}
input_overwrite_or_skip() { # Validation of the specified option (overwrite existing file or skip) from the user
	overwriteOrSkip=""
	local validInput="^[1-2]{1}$"
	local err="Invalid input! Please choose from the options below (1 or 2):\n"
	until [[ $overwriteOrSkip =~ $validInput ]]; do
		echo -e "The file \"$1\" already exists. Do you want to:\n"
		echo -e "[1] Overwrite the existing file\n[2] Skip this file\n"
		read -p "Enter number to proceed: " overwriteOrSkip 
		disp_error_regex "$overwriteOrSkip" "$validInput" "$err"
	done
}
input_user_option() { # Validation of the specified item of the main menu from the user
	userOption=""
	local validInput="^[1-5]{1}$"
	local err="Specified input is invalid! Please choose from options 1 to 5:\n"
	until [[ $userOption =~ $validInput ]]; do
		main_menu
		disp_error_regex "$userOption" "$validInput" "$err"
	done
}
input_dir() { # Validation of the specified directory name
	if ! [[ -z $dirName ]] && [[ $dirName =~ $validInput ]]; then # If directory name is not empty and valid
		local changeDir=""
		local validInput="^[YN]{1}$"
		local err="Invalid input! Please choose from the options below [Y - Yes, N - No]:\n"
		until [[ $changeDir =~ $validInput ]]; do
			echo -e "Directory has already been specified. All files will be downloaded in \"$dirName\".\n"
			read -p "Do you want to change this (Y/N)? " changeDir
			disp_error_regex "$changeDir" "$validInput" "$err"
		done
		clear
		if [[ $changeDir = 'Y' ]]; then
			local oldDirName=$dirName
		fi
	fi
	# If directory doesn't exist yet or user wants to change the specified directory
	if [[ -z $dirName ]] || [[ $changeDir = 'Y' ]]; then
		dirName="" # Sets directory name variable to empty 
		local validInput="^[a-zA-Z0-9_\-]+$"
		local err="Invalid input! \nLetters, numbers, hyphens & underscores are the only 
		accepted characters in the directory name.\nExample: Random_dir, Folder123, my-folder\n"
		# User is asked repeatedly until a valid directory name is specified
		until [[ $dirName =~ $validInput ]]; do
			read -p "Enter name of directory to store all downloaded files: " dirName
			disp_error_regex "$dirName" "$validInput" "$err"
		done
		if [[ $oldDirName = $dirName  ]]; then # If the user specified the same directory name as the last one
			sleep 1 && echo -e "\nDirectory name unchanged."
			sleep 1 && echo -e "\nDownloaded file(s) will be stored in the \"$dirName\" directory." && sleep 2
			clear
		else
			dir_exists "$dirName" # Calls the function to handle the directory name
		fi
	fi
}
dir_exists() { # Validation of the directory name if it exists
	# Parameter: $1 (directory name)
	if ! [[ -d $1 ]]; then # Check if it's NOT an existing directory
		mkdir "$1" && sleep 1 && echo -e "\n\"${1}\" has been created.\n"	# Creates the directory	if directory doesn't exist
	else
		sleep 1 && echo -e "\n\"${1}\" directory found.\n" # Tells the user that the directory has been found if directory exists
	fi
	sleep 1 && echo "Downloaded file(s) will be stored in the \"${1}\" directory."
	sleep 2
	clear
}
is_image_valid() { # Validation of the specified image if it exists in the list
	# Parameter: $1 (specified image thumbnail)
	for validImg in "${validImgList[@]}"; do
		if [[ $1 = $validImg ]]; then
			echo "Valid" && break
		fi
	done
}
#################################### ERROR HANDLING FUNCTIONS ########################################
disp_error_regex() { # Function to show the necessary action needed from the user
	# Parameters: $1 (user input), $2 (valid input), $3 (error message)
	if ! [[ $1 =~ $2 ]]; then
		clear && echo -e $3
	fi
}
#################################### MAIN CODE ########################################
prevCmdExitCode=$? # Variable that gets the status of the last running command
validImgList=($(fetch_valid_images)) # Initialise list globally containing valid thumbnail digits (0200 to 0674)
clear
until [[ $userOption -eq 5 ]]; do # Continues to ask user to choose from the main menu until the value 5 (exit) is entered
	input_user_option
	case $userOption in
		1) specific_thumb_view;; # Download a specific thumbnail
		2) img_range_view;; # Download images within a given range
		3) all_thumb_view;; # Download all images
		4) clean_up_view;; # Clean up all files
		5) exit_view;; # Exit program
	esac
done
exit 0
