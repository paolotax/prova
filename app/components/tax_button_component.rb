# frozen_string_literal: true

class TaxButtonComponent < ViewComponent::Base
  
  attr_reader :caption, :svg_file, :color, :url, :data_attr, :style, :target, :type
  
  def initialize(caption: nil, svg_file: nil, color:, url: nil, data_attr: {}, enabled: true, style: nil, target: nil, type: :link, orientation: "vertical")      
    @caption = caption
    @svg_file = svg_file
    @color = color
    @url = url
    @data_attr = data_attr
    @enabled = enabled
    @style = style
    @target = target
    @type = type
    if caption == "Elimina"
      @style = :button
    end
  end


  def css_class
    class_names(
      "flex sm:flex-col items-center gap-x-2
        text-sm text-center font-semibold cursor-pointer 
        transition duration-150 ease-in-out
        focus:outline focus:outline-2 focus:outline-offset-2": true,
      
      "bg-blue-600 text-white hover:bg-blue-500 active:bg-blue-700 
        focus:outline-blue-600": color == "blue",

      "bg-white text-black hover:bg-gray-200 active:bg-gray-100": color == "white",

      "bg-green-600 text-white hover:bg-green-500 active:bg-green-700 
        focus:outline-green-500": color == "green",

      "bg-yellow-300 text-yellow-700 hover:bg-yellow-200 active:bg-yellow-200 
        focus:outline-yellow-200": color == "yellow",

      "bg-red-600 text-white hover:bg-red-500 active:bg-red-600 
        focus:outline-red-600": color == "red",

      "bg-cyan-600 text-white hover:bg-cyan-500 active:bg-cyan-600 
        focus:outline-cyan-600": color == "cyan",

      "bg-purple-600 text-white hover:bg-purple-500 active:bg-purple-600 
        focus:outline-purple-600": color == "purple",

      "bg-pink-600 text-white hover:bg-pink-500 active:bg-pink-600 
        focus:outline-pink-600": color == "pink",

      "bg-gray-500 text-white hover:bg-gray-400 active:bg-gray-400 
        focus:outline-gray-400": color == "gray",        
      
        "border-none shadow-none bg-none text-gray-500 hover:text-gray-900 
        focus:outline-none": color == "transparent",

      "rounded-md shadow-md  py-2 px-3": style != :rounded,
      
      "rounded-full p-1": style == :rounded
    )
  end
 
end