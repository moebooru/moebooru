import { isWebkit } from '../utils/browser'
import ImgPoolHandlerDummy from './img_pool_handler_dummy'
import ImgPoolHandlerWebKit from './img_pool_handler_webkit'

# Create an image pool handler.  If the URL hash value "image-pools" is specified,
# force image pools on or off for debugging; otherwise enable them only when needed. 
export default ImgPoolHandler = ->
  use_image_pools = isWebkit()
  hash_value = UrlHash.get('image-pools')

  if hash_value?
    use_image_pools = hash_value != '0'

  if use_image_pools
    new ImgPoolHandlerWebKit(arguments)
  else
    new ImgPoolHandlerDummy(arguments)
