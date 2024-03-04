#  Refermate

This will serve as installation instructions for the new swift client. 

1. Navigate to the signing and capability section of each target. the provisioning profile, team, signing certificate and bundle identifiers should be updated to refermates credentials. 
2. Import Refermate-anywhere to the resources folder. 

3. I have modified the webpack module to output safari builds to a Resources directory. When the Refermate Extension's Resources folder is selected in the right hand panel's inspector view you should be able to update the reference path by clicking the foler icon under the location property. You can also replicate this behavior with the following command on mac. 

Build the application with the default refermate target (at least once) this will launch the Refermate application and add the extension to safari to be toggled. 

Optional. You can add a new build scheme which will build the Refermate Extension target. this option will present a list of applications to attach the process to. Make sure you select Safari. A new instance of safari will be launched using the settings from your previous instance of safari (If refermate is disabled in the original instance it will be disabled in the new instance and enabled if enabled in the original instance). 

4. Modifying the javascript. All modifications have been either wrapped in conditionals so that they are specific to the mac safari environment or they are housed within the shim function which is only loaded if the chrome namespace is not already defined. 


