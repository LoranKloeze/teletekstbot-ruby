module Services
  class CropImageService
    include Magick
    CROP_X = 50
    CROP_Y = 110
    CROP_WIDTH = 483
    CROP_HEIGHT = 525

    def initialize(path, page_nr)
      @path = path
      @page_nr = page_nr
    end

    def crop
      img = Image.read(@path)[0]
      img = img.crop(CROP_X, CROP_Y, CROP_WIDTH, CROP_HEIGHT)
      result_path = File.join(App::DATA_LOCATION, "cropped_#{@page_nr}.png")
      img.write(result_path)
      result_path
    end
  end
end
