# Building Cloud Native RPA's in Python using "Destructable Infrastructure"


In this article we will be:
- Setting up a virtual desktop to develop and run our RPA. Our RPA will run in a linux virtual desktop running inside a docker container. This allows us to decouple our code from our infrastructue as much as we can and ensure a "cloud-native" RPA.
- Build an RPA that downloads financial data from the SEC official website. Since the SEC database is called EDGAR we will call this RPA the "EDGAR_investigator".
- Overview specific functionality of the pybotlib library.

Requirements:
- Basic understanding of Python, RPA, and Business Processes
- Docker Desktop or Docker and Compose installed on a server (To run and develop our cloud native RPA)

For an overview of what an RPA is and some best practices when developing them check out my article here.

# Basics
Pybotlib provides a high level wrapper over several python libraries and imposes some best practices for developing RPA’s in Python. Let's go over some basics that every pybotlib RPA will have to go through. Once we are done we will start to build our cloud native RPA using python code and pre built docker images.

Instead of having decoupled tasks that are sequentially executed, in pybotlib you create a single “Virtual Agent” object that maintains overall state and behaviour that is needed to execute a business process. It is a representation of your RPA and its functionality. To create a VirtualAgent object you must specify the following parameters:

```
bot_name: A unique identifier for the RPA
downloads_directory: Where to store files downloaded through the internet
firefoxProfile: The directory on the host machine where firefox can find the profiles.ini 
file and instantiate a profile while loading the firefox webdriver. Usually located at /home/$USER/.mozilla/firefox
```

All actions are performed through the single object instance ```pybotlib.VirtualAgent```. In the example below the object is called mybot. Once we create our VirtualAgent object we wil proceed to create a log file for it to log messages to and finally open a webbrowser. To start browsing the web with the RPA you must call the get_geckodriver script that downloads the latest version of the firefox-geckodriver and places it in the current working directory. No dependancy is needed to create the RPA log file.

If you are running Linux you can try this code out on your machine, if your a mac or windows user we will spin up a virtual linux destkop in the next section.

The following code presents what most RPA scripts should start with using pybotlib. It imports necesary packages, downloads the latest geckodriver, istansiates the VirtualAgent, initializes a web driver, and finally goes to access some website (in this case google.com).


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
  downloads_directory=,
  # In order to load specific profiles from host machine
  firefoxProfile="/home/$USER/.mozilla/firefox" )
# Start a web browser that can be accessed via mybot.driver or other mybot methods
mybot.initialize_driver()
mybot.get("http://www.google.com")
mybot.log("I am accessing google")
```

Once we have instantiated our RPA we will continue to program and coordinate the set of activites it needs to conduct. At the very end of our script we will do some cleaning up:

``` python
mybot.driver.quit()
mybot.log_completion()
```

At any point during our RPA scripts the selenium webdriver that controls firefox can be accessed through pybotlib.driver or you can call other methods on top of the webdriver.
Some convinience methods are to make navigating web pages easier, one of them is ```VirtualAgent.find_by_tag_and_attr()```. 

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

# Setting up our enviornment
Now that we know the basics let's start creating our RPA code. It is best practice to have our entire RPA run by a single entry point such as a python program called run_RPA.py or similar. We will organize our code in order to achieve this. 

It is also best practice to decouple your input/output data and make your RPA execution as stateless as possible. Any RPA we develop should be able to spin up, “check” if there is pending work to do, and execute this work accordingly with minimum human interaction.

Using a cloud file store is the best approach to decoupling input and output data. In this example we will use a Google Sheets spreadsheet tab as the input of our business process and we will spin up a minio object storage container listening on port 9000 to store our output data files. Our input file will be a spreadsheet containing what companies need to be looked up and our output will simply be a folder containing the SEC reports from said companies. Our RPA should be able to spin up, check if there are pending rows to process, process them, and then persist the output. Lets create the mutable infrastructure that our RPA will run on. A simple docker file containing two images will suffice, one container will run full ubuntu Desktop enviornment and the other one will run our file store (in the case we will use minio). We can use any type of object storage for our output as long as we design are RPA to be "destructable" in the sense that any data that needs persisted is stored somewhere outside the Desktop enviornment. It may be the case that for your organization having a central virtual desktop that contains all persisted data is more practical, but the larger you scale out RPA operations, the more convinient having an immutable infrastructure will be. We could have also used minio as our data input source but using a google sheet would be more user friendly than manully editing a spreadsheet and uploading it.

Now lets get back to coding....

First let's create a ```docker-compose.yml``` file that will specify the containers we will need. Running docker-compose up -d will pull the images and run the container in a dettached mode.
The contents of the file should be the following:

``` yml
version: '3'

services:

  virtual-desktop:
      image: dorowu/ubuntu-desktop-lxde-vnc:bionic-lxqt
      volumes:
        - ./robot:/home/robot
      ports:
        - 5910:5900
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
      - '9000:9000'
    volumes:
      - './minio/data/:/data'
    environment:
      - MINIO_ACCESS_KEY=V42FCGRVMK24JJ8DHUYG
      - MINIO_SECRET_KEY=bKhWxVF3kQoLY9kFmt91l+tDrEoZjqnWXzY9Eza
    command: server /data

```
Now all we have to do is start our containers and begin to develop our RPA.

``` sh
docker-compose up -d
```

Then check if they are all running correctly
``` sh
docker-compose ps
```
We can now connect to our virtual desktop using any VNC client. You can use RealVNC on windows or Mac. Ubuntu has a built in remote deskopt client that works wonders. The Desktop should be accesable via http://127.0.0.1:5910

# RPA Development

