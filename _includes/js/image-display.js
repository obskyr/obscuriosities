'use strict';

class ImageDisplay {
  constructor(image_display_element) {
    if (typeof image_display_element === 'undefined') {image_display_element = this.constructor.create_element();}

    this.image_display_element = image_display_element;
    this.image_container = this.image_display_element.getElementsByClassName('image-container')[0];
    this.enlarged_image = this.image_display_element.getElementsByTagName('img')[0];
    this.caption = this.image_display_element.getElementsByClassName('caption')[0];
    this.left_arrow = this.image_display_element.getElementsByClassName('arrow')[0];
    this.right_arrow = this.image_display_element.getElementsByClassName('arrow')[1];
    this.background = this.image_display_element.getElementsByClassName('background')[0];

    this.images = []
    this.cur_image_index = 0;
    this.active = !this.image_display_element.classList.contains('inactive');

    this.callback_previous_image = function() {this.display_image_no(this.cur_image_index - 1);}.bind(this);
    this.callback_next_image = function() {this.display_image_no(this.cur_image_index + 1);}.bind(this);
    this.callback_reveal_spoiler_via_current_image = this.reveal_spoiler_via_current_image.bind(this);
    this.callback_deactivate = this.deactivate_display.bind(this);

    document.addEventListener('keydown', function(event) {
      if (!this.active) {return;}
      switch (event.key) {
        case 'ArrowLeft':
          this.display_image_no(this.cur_image_index - 1);
          break;
        case 'ArrowRight':
          this.display_image_no(this.cur_image_index + 1);
          break;
        case 'Escape':
          this.deactivate_display();
          break;
      }
    }.bind(this), false);
  }

  append_image_elements(image_elements) {
    for (let i = 0; i < image_elements.length; i++) {
      let image_element = image_elements[i];
      this.append_image_element(image_element);
    }
  }

  append_image_element(image_element) {
    let cur_parent = image_element.parentElement;
    let spoiler_parent = null;
    while (cur_parent.tagName !== 'BODY') {
      if (cur_parent.classList.contains('spoilers')) {
        spoiler_parent = cur_parent;
        break;
      }
      cur_parent = cur_parent.parentElement;
    }

    if (image_element.tagName === 'IMG') {
      this.images.push([image_element, null, spoiler_parent]);
    } else {
      let img = image_element.getElementsByTagName('img')[0];
      let description = image_element.getElementsByClassName('caption')[0];
      description = description ? description.innerHTML : null;
      this.images.push([img, description, spoiler_parent])
    }

    let i = this.images.length - 1;
    this.images[i][0].addEventListener('click', function() {
      this.display_image_no(i);
    }.bind(this), false);
  }

  reveal_spoiler_via_current_image() {
    this.images[this.cur_image_index][2].classList.add('revealed');
    this.image_container.classList.add('revealed');
    this.image_container.removeEventListener('click', this.callback_reveal_spoiler_via_current_image);
  }

  display_image_no(i) {
    if (i < 0 || i >= this.images.length) {return;}
    this.cur_image_index = i;
    this.enlarged_image.src = this.images[i][0].src;
    this.enlarged_image.alt = this.images[i][0].alt;
    this.enlarged_image.title = this.images[i][0].title;

    let caption = this.images[i][1];
    caption ? this.caption.classList.remove('inactive') : this.caption.classList.add('inactive');
    this.caption.innerHTML = caption;

    this.update_spoiler_properties();

    i === 0 ? this.left_arrow.classList.add('inactive') : this.left_arrow.classList.remove('inactive');
    i === this.images.length - 1 ? this.right_arrow.classList.add('inactive') : this.right_arrow.classList.remove('inactive');

    this.activate_display();
  }

  update_spoiler_properties() {
    let spoiler_parent = this.images[this.cur_image_index][2];
    if (spoiler_parent && this.active) {
      this.image_container.classList.add('spoilers');
      if (spoiler_parent.classList.contains('revealed')) {
        this.image_container.classList.add('revealed');
      } else {
        this.image_container.addEventListener('click', this.callback_reveal_spoiler_via_current_image);
      }
      this.image_container.setAttribute('data-for', spoiler_parent.getAttribute('data-for'));
    } else {
      this.image_container.classList.remove('spoilers');
      this.image_container.removeAttribute('data-for');
      this.image_container.removeEventListener('click', this.callback_reveal_spoiler_via_current_image);
    }
  }

  activate_display() {
    if (this.active) {return;}
    this.active = true;
    this.left_arrow.addEventListener('click', this.callback_previous_image, false);
    this.right_arrow.addEventListener('click', this.callback_next_image, false);
    this.background.addEventListener('click', this.callback_deactivate, false);
    this.update_spoiler_properties();
    this.image_display_element.classList.remove('inactive');
  }
  
  deactivate_display() {
    if (!this.active) {return;}
    this.active = false;
    this.left_arrow.removeEventListener('click', this.callback_previous_image);
    this.right_arrow.removeEventListener('click', this.callback_next_image);
    this.background.removeEventListener('click', this.callback_deactivate);
    this.update_spoiler_properties();
    this.image_display_element.classList.add('inactive');
  }

  static create_element() {
    let image_display_element = document.createElement('div');
    image_display_element.innerHTML = "<div class='background'></div><div class='arrow left'></div><div class='image-container'><img><div class='caption'></div></div><div class='arrow right'></div>";
    image_display_element.classList.add('image-display');
    image_display_element.classList.add('inactive');

    let callback = function() {document.body.appendChild(image_display_element);}
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback);
    } else {
      callback();
    }

    return image_display_element;
  }
}

document.addEventListener('DOMContentLoaded', function() {
  let spoiler_tags = document.getElementsByClassName('spoilers');
  for (let i = 0; i < spoiler_tags.length; i++) {
    let tag = spoiler_tags[i];
    let cur_handler = function() {
      tag.classList.add('revealed');
      tag.removeEventListener('click', cur_handler);
    }
    tag.addEventListener('click', cur_handler, false);
  }
});
