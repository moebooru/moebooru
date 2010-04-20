#include <ruby.h>
#include <stdio.h>
#include <string.h>
#include <memory>
using namespace std;
#include "PNGReader.h"
#include "GIFReader.h"
#include "JPEGReader.h"
#include "Resize.h"
#include "Crop.h"
#include "ConvertToRGB.h"

static VALUE danbooru_module;

static VALUE danbooru_resize_image(VALUE module, VALUE file_ext_val, VALUE read_path_val, VALUE write_path_val,
		VALUE output_width_val, VALUE output_height_val,
		VALUE crop_top_val, VALUE crop_bottom_val, VALUE crop_left_val, VALUE crop_right_val,
		VALUE output_quality_val)
{
	const char * file_ext = StringValueCStr(file_ext_val);
	const char * read_path = StringValueCStr(read_path_val);
	const char * write_path = StringValueCStr(write_path_val);
	int output_width = NUM2INT(output_width_val);
	int output_height = NUM2INT(output_height_val);
	int output_quality = NUM2INT(output_quality_val);
	int crop_top = NUM2INT(crop_top_val);
	int crop_bottom = NUM2INT(crop_bottom_val);
	int crop_left = NUM2INT(crop_left_val);
	int crop_right = NUM2INT(crop_right_val);

	FILE *read_file = fopen(read_path, "rb");
	if(read_file == NULL)
		rb_raise(rb_eIOError, "can't open %s\n", read_path);

	FILE *write_file = fopen(write_path, "wb");
	if(write_file == NULL)
	{
		fclose(read_file);
		rb_raise(rb_eIOError, "can't open %s\n", write_path);
	}

	bool ret = false;
	char error[1024];

	try
	{
		auto_ptr<Reader> pReader(NULL);
		if (!strcmp(file_ext, "jpg") || !strcmp(file_ext, "jpeg"))
			pReader.reset(new JPEG);
		else if (!strcmp(file_ext, "gif"))
			pReader.reset(new GIF);
		else if (!strcmp(file_ext, "png"))
			pReader.reset(new PNG);
		else
		{
			strcpy(error, "unknown filetype");
			goto cleanup;
		}

		auto_ptr<Filter> pFilter(NULL);

		{
			auto_ptr<JPEGCompressor> pCompressor(new JPEGCompressor(write_file));
			pCompressor->SetQuality(output_quality);
			pFilter.reset(pCompressor.release());
		}

		{
			auto_ptr<Resizer> pResizer(new Resizer(pFilter));
			pResizer->SetDest(output_width, output_height);
			pFilter.reset(pResizer.release());
		}

		if(crop_bottom > crop_top && crop_right > crop_left)
		{
			auto_ptr<Crop> pCropper(new Crop(pFilter));
			pCropper->SetCrop(crop_top, crop_bottom, crop_left, crop_right);
			pFilter.reset(pCropper.release());
		}

		{
			auto_ptr<ConvertToRGB> pConverter(new ConvertToRGB(pFilter));
			pFilter.reset(pConverter.release());
		}

		ret = pReader->Read(read_file, pFilter.get(), error);
	}
	catch(const std::bad_alloc &e)
	{
		strcpy(error, "out of memory");
	}

cleanup:
	fclose(read_file);
	fclose(write_file);

	if(!ret)
		rb_raise(rb_eException, "%s", error);

	return INT2FIX(0);
}

extern "C" void Init_danbooru_image_resizer() {
  danbooru_module = rb_define_module("Danbooru");
  rb_define_module_function(danbooru_module, "resize_image", (VALUE(*)(...))danbooru_resize_image, 10);
}
