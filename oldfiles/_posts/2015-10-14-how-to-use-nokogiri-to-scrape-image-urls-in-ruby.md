---
title: "How to use Nokogiri to Scrape Image URLs in Ruby"
permalink: how-to-use-nokogiri-to-scrape-image-urls-in-ruby
categories: coding
---

Nokogiri is a pretty powerful set of tools for scraping data from websites. When used strategically, it can help you carry out competitive research, audit your websites, check dynamic data sets (e.g. stock prices, ebay prices) and a lot more. I’ve found it’s pretty easy to actually use and requires a pretty minimal level of understanding in Ruby to get use out of it, which is perfect for me because I’m not a professional web developer.

I’ll take you through a scenario of how I managed to use Nokogiri to scrape common web data and how it has helped me work smarter.

# Problem

One of the items I was tasked with was auditing dozens of different image galleries across just as many websites. Doing this one by one was painstaking and took forever, especially when you have to click image by image and look through each caption.  The process was repetitive and seemed like something that could be automated.

For this to work, you need Ruby installed as well as the nokogiri gems.

# Solution

The first step was to get something working in Ruby. Once I could do it for one hotel, it is just a matter of From there I’d make it web based with Rails.

The below ruby script, when run, just uses Nokogiri to output the Image URL based on the HREF tag being present in am image tag with the CSSclass of Gallery.

{% highlight ruby %}
require 'open-uri' #this is required to open the URLs we are going to scrape

#the next two lines are specific to my case.  ctyhocn is a code that differentiates the different URLs we are scraping.

ctyhocn = "LHRSPHI"
url = "http://www3.hilton.com/en/hotels/united-kingdom/" + ctyhocn + "/index.html"

#create an empty array to store the image urls in
img_urls = Array.new

#create an empty array to store impage captions in
img_captions = Array.new

#We are using both open-uri and nokogiri here.  Open-URI opens the URL and Nokogiri is parsing it so we can use its custom functions
doc = Nokogiri::HTML(open(url))

#the .css function will store all of the matches it finds in the array we created
img_urls = doc.css('.gallery img').map{ |i| i['src'] } #search through the CSS in the doc object for img tags with a class of Gallery and grab the element in its SRC tag
img_captions = doc.css('.gallery .image_alt').map{ |alt| alt } #grab the ALT element content from the CSS that contains gallery and image alt classes

#Prints out unique image urls
puts img_urls.uniq
{% endhighlight %}
