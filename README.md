# Building Cloud Native RPA's in Python using "Destructible Infrastructure"

In this article we will be:

- Setting up a virtual desktop to develop and run our RPA. Our RPA will run in a linux virtual desktop running inside a docker container. This allows us to decouple our code from our infrastructure as much as we can and ensure a "cloud-native" RPA.
- Build an RPA that downloads financial data from the SEC official website. Since the SEC database is called EDGAR we will call this RPA the "EDGAR_investigator".
- Ensure our RPA is decoupled form its persisted data and could potentially run on any infrastructure

Requirements:

- Basic understanding of Python, RPA, and Business Processes
- Docker Desktop or Docker and Compose installed on a server (To run and develop our cloud native RPA)

For an overview of what an RPA is and some best practices when developing them check out my article here.

# Introducing Pybotlib

Pybotlib provides a high level wrapper over several python libraries and imposes some best practices for developing RPA’s in Python. Let's go over some basics that every pybotlib RPA will have to go through. Once we are done we will start to build our cloud native RPA using python code and pre built docker images.

Instead of having decoupled tasks that are sequentially executed, in pybotlib you create a single “Virtual Agent” object that maintains overall state and behavior that is needed to execute a business process. It is a representation of your RPA and its functionality. To create a VirtualAgent object you must specify the following parameters:

- bot_name: A unique identifier for the RPA
- downloads_directory: Where to store files downloaded through the internet
- firefoxProfile: The directory on the host machine where firefox can find the profiles.ini
file and instantiate a profile while loading the firefox webdriver. Usually located at /home/$USER/.mozilla/firefox

All actions are performed through the single object instance `pybotlib.VirtualAgent`. In the example below the object is called mybot. Once we create our VirtualAgent object we wil proceed to create a log file for it to log messages to and finally open a web browser. To start browsing the web with the RPA you must call the get_geckodriver script that downloads the latest version of the firefox-geckodriver and places it in the current working directory. No dependency is needed to create the RPA log file.

We will spin up a virtual desktop to run the following code in the next section.

The following code presents what most RPA scripts should start with using pybotlib. It imports needed packages, downloads the latest geckodriver, instantiates the VirtualAgent, initializes a web driver, and finally goes to access some website (in this case google.com).

```python
import os
from pybotlib import VirtualAgent
from pybotlib.utils import get_geckodriver

# Downloads the geckodriver
get_geckodriver()
# Any file downloaded will be saved to the current working dir
# under a folder called bot_downloads
bot_download_dir = os.path.join(os.getcwd(),"bot_downloads")

mybot=VirtualAgent(
  bot_name="my_first_robot",
  downloads_directory=bot_download_dir,
  # In order to load specific profiles from host machine
  firefoxProfile="/home/$USER/.mozilla/firefox" )
# Start a web browser that can be accessed via mybot.driver or other mybot methods
mybot.create_log_file()
mybot.initialize_driver()
mybot.get("http://www.google.com")
mybot.log("I am accessing google")
```

Once we have instantiated our RPA we will continue to program and coordinate the set of activities it needs to conduct. At the very end of our script we will do some cleaning up:

```python
mybot.driver.quit()
mybot.log_bot_completion()
```

At any point during our RPA scripts the selenium webdriver that controls firefox can be accessed through pybotlib.driver or you can call other methods on top of the webdriver.
Some convenience methods are to make navigating web pages easier, one of them is `VirtualAgent.find_by_tag_and_attr()`.

This method will return all HTML elements with a specific tag and attribute that corresponds to some evaluation string you decide. The VirtualAgent object must have already been instantiated and a webdriver initialized.
If we wanted to search for all buttons on a webpage with className = “hugebutton” you would use the following code:

```python
mybutton = mybot.find_by_tag_and_attr("button", "className", "hugebutton", 1)
```

You can also directly interact with the webdriver and use any of the Selenium methods that are provided.

```python
# Example
mybot.driver.refresh()
```

# Setting up our environment

Now that we know the basics let's start creating our RPA code. It is best practice to have our entire RPA run by a single entry point such as a python program called run_RPA.py or similar. We will organize our code in order to achieve this.

It is also best practice to decouple your input/output data and make your RPA execution as stateless as possible. Any RPA we develop should be able to spin up, “check” if there is pending work to do, and execute this work accordingly with minimum human interaction.

Using a cloud file store is the best approach to decoupling input and output data. In this example we will use a Google Sheets spreadsheet tab as the input of our business process and we will spin up a minio object storage container listening on port 9000 to store our output data files. Our input file will be a spreadsheet containing what companies need to be looked up and our output will simply be a folder containing the SEC reports from said companies. Our RPA should be able to spin up, check if there are pending rows to process, process them, and then persist the output. Lets create the mutable infrastructure that our RPA will run on. A simple docker file containing two images will suffice, one container will run full ubuntu Desktop environment and the other one will run our file store (in the case we will use minio). We can use any type of object storage for our output as long as we design are RPA to be "destructible" in the sense that any data that needs persisted is stored somewhere outside the Desktop environment. It may be the case that for your organization having a central virtual desktop that contains all persisted data is more practical, but the larger you scale out RPA operations, the more convenient having an immutable infrastructure will be. We could have also used minio as our data input source but using a google sheet would be more user friendly than manually editing a spreadsheet and uploading it.

Now lets get back to coding....

First let's create a `docker-compose.yml`.

The contents of the file should be the following:

```yml
version: "3"

services:
  virtual-desktop:
    image: dorowu/ubuntu-desktop-lxde-vnc:bionic-lxqt
    volumes:
      - ./robot:/home/robot
    ports:
      - "5910:5900"
    environment:
      - USER=robot
      - PASSWORD=robot
      - MINIO_ACCESS_KEY=V42FCGRVMK24JJ8DHUYG
      - MINIO_SECRET_KEY=bKhWxVF3kQoLY9kFmt91l+tDrEoZjqnWXzY9Eza
  minio:
    hostname: minio
    image: minio/minio
    container_name: minio
    ports:
      - "9000:9000"
    volumes:
      - "./minio/data/:/data"
    environment:
      - MINIO_ACCESS_KEY=123456
      - MINIO_SECRET_KEY=password
    command: server /data
```

Now all we have to do is start our containers and begin to develop our RPA.

```sh
docker-compose up -d
```

```
Creating network "howtomakearobot_default" with the default driver
Creating howtomakearobot_virtual-desktop_1 ...
Creating minio ...
Creating howtomakearobot_virtual-desktop_1
Creating minio ... done
```

Then check if they are all running correctly

```sh
docker-compose ps
```

```
        Name                  Command          State          Ports
---------------------------------------------------------------------------
howtomakearobot_virtu   /startup.sh            Up      0.0.0.0:5910->5900/t
al-desktop_1                                           cp, 80/tcp
minio                   /usr/bin/docker-       Up      0.0.0.0:9000->9000/t
                        entrypoint ...                 cp
```

We can now connect to our virtual desktop using any VNC client. You can use RealVNC on windows or Mac. Ubuntu has a built in remote desktop client that works wonders. The Desktop should be accessible via `http://127.0.0.1:5910`. If you wanted to access the Desktop via a browser you can map the noVNC http port and access it via a browser. Please note that security is off by default. The User created in the virtual Desktop is called robot and its password is robot. This can be changed in the docker-compose.yml file.

An initial configuration to install python 3.7 and set it as the default version is needed. A quick check to make sure firefox will run properly is recommended. Running with very limited resources can cause issues.

Once the containers are up connect to the Ubuntu container via Remote Desktop and open up a terminal (Shift + Ctrl + t). Run the following commands for initial configuration:

```sh
sudo apt-get update && sudo apt-get install  python3.7 nano python3-pip curl wget git && alias python=python3.7 && echo 'alias python=python3.7' >> /home/robot/.bashrc
# Remember that the password for robot is robot
python -m pip install pybotlib ipython
```

In these command we installed python 3.7 set it as the default command called when using the python word and installed pybotlib from the python package index. We also installed the Ipython interpreter for debugging purposes. We can open the interactive interpreter and check if our installation was correct.

First start IPython by running the following command:

```
python - m IPython
```

Then type the following command and ensure it executes successfully.

```py
import pybotlib
```

# RPA Development

Lets set up a directory structure in the virtual desktop and call it edgar-RPA. We will create one file called run_RPA.py.
This can all be done from the command line. Open up another terminal inside the virtual desktop and execute:

```sh
mkdir /home/robot/Desktop/edgar-RPA
touch /home/robot/Desktop/edgar-RPA/run_RPA.py
```

We will be writing our RPA within the run_RPA.py file. You can either edit the document on your host machine and copy and paste your code through the remote client into the default text editor that runs within the virtual desktop or you can edit directly within the virtual desktop. If you choose the later I recommend downloading atom onto the virtual desktop to use as a text editor as the default program is quite horrendous for writing code. If you want to go retro you can just write code within the terminal from within the virtual desktop using nano or vim.

If you want to use nano make sure to install it from within the terminal of the virtual Desktop.

```
sudo apt-get install nano
```

My preference is to just use visual studio code or atom on a host machine and copy and paste the text from within the editor.

Let's populate run_RPA.py with our initial pybotlib boilerplate code from the previous sections. We'll add a few lines at the end to exit out the web browser.

```python
import os
from pybotlib import VirtualAgent
from pybotlib.utils import get_geckodriver
from time import sleep
# Downloads the geckodriver
get_geckodriver()
# Any file downloaded will be saved to the current working dir
# under a folder called bot_downloads
bot_download_dir = os.path.join(os.getcwd(),"bot_downloads")

mybot=VirtualAgent(
  bot_name="my_first_robot",
  downloads_directory=bot_download_dir,
  # In order to load specific profiles from host machine
  firefoxProfile="/home/robot/.mozilla/firefox" )
# Start a web browser that can be accessed via mybot.driver or other mybot methods
mybot.create_log_file()
mybot.initialize_driver()
mybot.get("http://www.google.com")
mybot.log("I am accessing google")
sleep(5)
mybot.log_bot_completion()
mybot.driver.quit()
```

Now lets test out that everything works up to now by running `python run_RPA.py` from within the terminal in the virtual Desktop. Make sure our current working directory is the folder containing our code. Firefox should open up and access google then shut down after 5 seconds. You can also check the exit status of the program by typing `echo $?` Anything other than 0 means something went wrong.

Before we proceed lets initialize the project folder as a git repository that can be cloned in and excecuted on potentially and instance of a Ubuntu Virtual Desktop.
You can use any online repo you would like, in this case I will just create a private github repository in the github UI with the following url https://github.com/dkatz23238/testfinanceRPA.git and then execute the following command from within the VD where my work is currently being done.

```sh
cd /home/robot/Desktop/edgar-RPA
git init
git add .
git commit -m "first commit"
git remote add origin https://github.com/dkatz23238/testfinanceRPA.git
git push -u origin master
```

Now we can track the progress of our code and version it.

Lets begin by creating the functional elements of our RPA. I recommend we create a separate file called RPA_activities.py from which we import our activities into our run_RPA.py file and have our RPA be executed from there.

```sh
touch /home/robot/Desktop/edgar-RPA/RPA_activities.py
```

As previously mentioned this RPA will download specific financial reports form the SEC's website. Any RPA will usually need to input and output business data, the choices of what to use can vary but for this RPA I will choose to use a Google Sheets Spread sheet as input and use the minio object store for document output. We can create a spreadsheet in GSheet and produce a view only URL for the RPA to use. This data can be read by our RPA into pandas.DataFrame using `pybotlib.utils.pandas_read_google_sheets(sheet_id)`

The functional elements of our RPA will be a function that takes in the VirtualAgent instance as an input and downloads a series of reports from the SEC's website by navigating the front end of the website. A second function will be defined to instantiate our VirtualAgent and then persist the data to our corresponding store of choice. We will have to pass the RPA some env variables that it will use to access different attached resources. For now we will define them in the shell before executing our RPA. First lets make some modifications to our files in order to have our activities in one file and then our second file will simply import the activities and execute them in the way we defined. In this article I will not dive into the specifics of how the RPA downloads the reports, this is purely done by navigating the front end via the selenium webdriver and helper functions provided within pybotlib. 

RPA_activities.py

```py

import os
import glob
import datetime
import time

from shutil import move as moveFile
from shutil import rmtree as removeDirectoryAndContents
from shutil import make_archive
from pybotlib import VirtualAgent
from pandas import DataFrame, read_excel, read_csv
from pybotlib.utils import get_geckodriver, pandas_read_google_sheets
from os.path import join
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import ElementNotVisibleException
import traceback

from pybotlib.utils import create_minio_bucket, write_file_to_minio_bucket
get_geckodriver()
SLEEPSECONDS = 5
# First let's get the enviornment variables
try:
# Minio File store URI for uploading the output files
    MINIO_URI = os.environ["MINIO_URL"]
    MINIO_ACCESS_KEY = os.environ["MINIO_ACCESS_KEY"]
    MINIO_SECRET_KEY = os.environ["MINIO_SECRET_KEY"]
    MINIO_OUTPUT_BUCKET_NAME = os.environ["MINIO_OUTPUT_BUCKET_NAME"]
    # Business logic input file decoupled using Google Drive Sheets
    GSHEET_ID = os.environ["GSHEET_ID"]
except KeyError as e:
    print("You must instansiate enviornment variables in env-vars.sh")
    raise e

def getFinancialReports(my_bot, tickers, report):

    """ Downloads an invidiual report from SEC website and saves it to downloads directory """

    for ticker in tickers:
        my_bot.log("searching edgar for %s" % ticker)
        url = "https://www.sec.gov/edgar/searchedgar/companysearch.html"

        my_bot.get(url)
        searchBox = (
            my_bot.find_by_tag_and_attr(
                tag="input",
                attribute="id",
                evaluation_string="cik",
                sleep_secs=SLEEPSECONDS)
            )[0]
        searchBox.clear()
        searchBox.send_keys(ticker, Keys.ENTER)
        typeBox = (
            my_bot.find_by_tag_and_attr(
                tag="input",
                attribute="id",
                evaluation_string="type",
                sleep_secs=SLEEPSECONDS)
            )[0]
        time.sleep(4)
        typeBox.send_keys(report, Keys.ENTER)

        interactiveFields = (
            my_bot.find_by_tag_and_attr(
                tag="a",
                attribute="id",
                evaluation_string="interactiveDataBtn",
                sleep_secs=SLEEPSECONDS)
            )
        interactiveFields[0].click()
        exportExcel = (
            my_bot.find_by_tag_and_attr(
                tag="a",
                attribute="class",
                evaluation_string="xbrlviewer",
                sleep_secs=SLEEPSECONDS)
            )
        exportExcel = [
            el for el in exportExcel if el.text == "View Excel Document"
            ]

        exportExcel[0].click()

        while not len(glob.glob(os.path.join(my_bot.downloads_dir,  r"*.xlsx"))) > 0:
            time.sleep(3)
            print("waiting for download")
            exportExcel[0].click()

        if os.path.exists(os.path.join(my_bot.downloads_dir,  ticker)):
            pass
        else:
            os.mkdir(os.path.join(my_bot.downloads_dir,  ticker))

        downloadedReport = glob.glob(
            os.path.join(my_bot.downloads_dir,  r"*.xlsx")
            )[0]

        destination = os.path.join(my_bot.downloads_dir,  ticker,"Financial_Report.xlsx")

        moveFile(downloadedReport, destination)
        time.sleep(5)

def run_robot():

    input_dataframe = pandas_read_google_sheets(GSHEET_ID)

    try:
        # First Stage: Download financial transcripts from EDGAR database
        my_bot = VirtualAgent(
                bot_name="EDGAR_investigator_bot",
                downloads_directory=os.path.join(os.getcwd(), "bot_downloads"),
                firefoxProfile=os.path.join("/","home",os.environ["USER"], ".mozilla", "firefox"))
        # Creates log file to log an auditable trail and collect errors
        my_bot.create_log_file()
        # Reads tickers from excel into a list
        tickers = input_dataframe["Company Ticker"].tolist()
        # Initializes the Chrome webdriver
        my_bot.initialize_driver()
        # Collects data from SEC edgar website
        getFinancialReports(my_bot, tickers, report="10-Q")
        # Quits out of driver to finalize stage
        my_bot.quit_driver()
        time.sleep(5)
        # Reads out company names from excel into a list
        my_bot.log_bot_completion()
        # print("Robot Complete!")
        # print(read_csv(my_bot.logfile_path, encoding="utf-8").set_index("idx"))

        ########## CLEAN UP AND OUTPUT DATA PERSISTANCE ##########
        create_minio_bucket(MINIO_URI, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_OUTPUT_BUCKET_NAME )

        # Write geckodriver logs to minio
        if os.path.exists("./geckodriver.log"):
            write_file_to_minio_bucket(
                MINIO_URI,
                MINIO_ACCESS_KEY,
                MINIO_SECRET_KEY,
                MINIO_OUTPUT_BUCKET_NAME,
                "geckodriver.log")
                # Write pybotlib logs to minio

        output_data_filename = "pybotlib-logs"
        compression_method = "zip"
        archived_file = make_archive(output_data_filename, compression_method, "./pybotlib_logs/")
        write_file_to_minio_bucket(
            MINIO_URI,
            MINIO_ACCESS_KEY,
            MINIO_SECRET_KEY,
            MINIO_OUTPUT_BUCKET_NAME,
            "%s.%s" % (output_data_filename, compression_method)
            )


        for f in glob.glob("./pybotlib_logs/.*csv"):
            write_file_to_minio_bucket(
                MINIO_URI,
                MINIO_ACCESS_KEY,
                MINIO_SECRET_KEY,
                MINIO_OUTPUT_BUCKET_NAME,
                f)
        # Business data output is stored in bot_downloads.
        # We will zip this folder as stock-data.zip and upload it as a single file.
        output_data_filename = "financial-data"
        compression_method = "zip"
        archived_file = make_archive(output_data_filename, "zip", "./bot_downloads/")
        write_file_to_minio_bucket(
            MINIO_URI,
            MINIO_ACCESS_KEY,
            MINIO_SECRET_KEY,
            MINIO_OUTPUT_BUCKET_NAME,
            "%s.%s" % (output_data_filename, compression_method)
            )
        # Clean up and delete all the files we need
        removeDirectoryAndContents("./pybotlib_logs", ignore_errors=True)
        removeDirectoryAndContents("./bot_downloads", ignore_errors=True)
        # Remove the zip file we uploaded to minio
        for f in glob.glob("./*.log"):
            os.remove(f)
        for f in glob.glob("./*.zip"):
            os.remove(f)

    except Exception as e:
        # Logs exceptions
        my_bot.log(message="ERROR: %s" %str(e), tag="execution")

        try:
            my_bot.driver.quit()
        except:
            pass
        # Print out stack trace
        traceback.print_exc()
        # raise error if fails
        raise e

```

### run_RPA.py

```py
# Accesses them to ensure they are accessible by our script
env_vars = (
        MINIO_URI,
        MINIO_ACCESS_KEY,
        MINIO_SECRET_KEY,
        MINIO_OUTPUT_BUCKET_NAME,
        GSHEET_ID
)

# DEBUG ONLY
# print("ACCESSED ENVIORNMENT VARIABLES")
# for var in env_vars:
    # print(var)

run_robot()
```

As you see we have moved our code and business logic into the RPA_activites.py file and our run_RPA.py file simply will call and run the RPA as an entrypoint to our RPA.

For specifics on the actual ways we navigating the front end of the SEC webpage refer to the Selenium webdriver documentation as well as the README.md of pybotlib in github.


At this point all we have to do is define our environment variables and execute our RPA. Remember that we have a minio instance running where the RPA will persist the data.

Our RPA code makes use of environment variables that must be predefined in order for the RPA to access certain attached resources or for other reasons. Environment variables a great tool to build code that is can easily become as stateless as possible and use certain information such as URLs, keys, and passwords, to access attached resources. This is an essential concept of the 12-factor application development methodology that you can read more about from here


The following code executed from within the Virtual Desktops terminal should run our RPA form end to end.

``` sh
export MINIO_URL=minio;
export MINIO_ACCESS_KEY=123456;
export MINIO_SECRET_KEY=password;
export MINIO_OUTPUT_BUCKET_NAME=financials;
export GSHEET_ID=1pBecz5Db9eK0QDR_oePmamdaFtEiCaO69RaE-Ozduko;
export DISPLAY=:1;

python run_RPA.py
```

Once our RPA has completed we can access the files through a browser in the minio URL.
Our final step is to create a single shell script that can be executed anywhere from within a Virtual Desktop and run our RPA. 

All we need to do is add the above commands to a shell script that we be the single entrypoint to our RPA. We can push the whole contents of our RPA to the git repository and test cloning the repository from scratch and re executing our RPA. This will ensure that our RPA will satisfy the "destructibility condition". Let's make our RPA a little more security friendly by not having it print our the env variables before doing our final push.

For now this RPA is enough to demonstrate the purposes of this article however enhancements to this RPA would be to add testing, better exception handling and automated deployment. These topic will be covered in the next article.

Our final project will contain the following files:

edgar-rpa
  run_RPA.py
  RPA_activites.py
  run_RPA.sh

Changing directory into the folder and running the /bin/bash run_RPA.sh should run our end to end process. Finally we can add our initial commands that downloads dependencies and assigns aliases to our run_RPA.sh script, push it to git and do a clone and re-run test to assure that our RPA could run on any infrastructure in any docker container running our specific virtual desktop image.

We can also add an environment variables to our run_RPA.sh in order to execute our RPA from a remote shell without needing to log into a GUI. To do this we can just add the following environment variable to our run_RPA.sh script. This has already been added above.
```sh
export DISPLAY=:1
```
Our final run_RPA.sh script will look like this:

``` sh
#! /bin/bash
export MINIO_URL=minio;
export MINIO_ACCESS_KEY=123456;
export MINIO_SECRET_KEY=password;
export MINIO_OUTPUT_BUCKET_NAME=financials;
export GSHEET_ID=1pBecz5Db9eK0QDR_oePmamdaFtEiCaO69RaE-Ozduko;
export DISPLAY=:1;

# Pip will only use the current users directory
python3.7 -m pip install --user robot --no-cache-dir pybotlib

python3.7 run_RPA.py

```


From the host machine we can now shell into the Virtual Desktop and execute our RPA remotely.
To test this functionality out we can access a running shell from our host machine to our virtual desktop that the RPA is intended to run on. In our directory containing the docker-compose-yml file the following command will start a shell in our client from our host. Note that the new shell that spawns corresponds to the container and not the host machine. From here we can cd into the code directory folder and run our RPA as a bash command and observe through our remote desktop client that our start normally as if you were logged in through the user interface.
```
docker-compose exec --user robot virtual-desktop /bin/bash
```
From within the new shell we can navigate to our code directory and run the shell script.

```
sudo -H -u robot bash -c bash run_RPA.sh
```

At this point we can deploy a virtual desktop image to any infrasturcture that supports docker and clone our newly created RPA and execute it. This potentially will allow you to save a lot of money on compute time costs as you can scale an army of RPA's at your need to match demand for the work.