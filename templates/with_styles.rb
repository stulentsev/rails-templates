file 'app/assets/stylesheets/layout.css', <<-CSS
.box_shadow {
    box-shadow: 5px 5px 10px rgba(0, 0, 0, 0.6);
    -moz-box-shadow: 5px 5px 10px rgba(0, 0, 0, 0.6);
    -webkit-box-shadow: 5px 5px 10px rgba(0, 0, 0, 0.6);
}

#pageLayout {
    margin: 0 auto;
    width: 1000px;
}

#pageHeader {
    background-color: #32608A;
    background-position: left top;
    background-repeat: no-repeat;
    height: 45px;
    position: relative;
    color: white;
    width:1015px;
    margin:0 auto;
    -moz-border-radius: 0px 0px 10px 10px;
    -webkit-border-radius: 0px 0px 10px 10px;
    border-radius: 0px 0px 10px 10px;
}

#pageHeader a {
    color: white;
}

.headNav a, .headNav div {
    background: url("../images/header_divider.gif") no-repeat scroll left top transparent;
    color: #DAE1E8;
    display: block;
    float: right;
    font-size: 11px;
    font-weight: bold;
    margin: 0;
    padding: 11px 9px;
}

#home {
    left: 0;
    position: absolute;
    top: 0; /*width: 153px;*/
    padding-left: 8px;
    padding-top: 8px;
}

.headNav {
    line-height: 20px;
    margin: 0;
    float: right;
    padding: 0 5px 0 0;
    text-align: right;
}

#left_sidebar {
    float: left;
    margin: 3px 0 0 4px;
    padding-bottom: 10px;
    width: 130px;
}

#left_sidebar li a {
    background: none repeat scroll 0 0 white;
    border-color: #FFFFFF -moz-use-text-color -moz-use-text-color;
    border-right: 0 none;
    border-style: solid none none;
    border-width: 1px 0 0;
    display: block;
    padding: 3px 3px 3px 6px;
}

a, span.link, span.linkover {
    color: #2B587A;
    cursor: pointer;
    text-decoration: none;
}

#nav {
    list-style: none outside none;
    margin: 0 0 1em;
    padding: 0;
}

#header {
    background-color: #EEE5B8;
    background-image: url("../images/header_yellow.gif");
    background-position: left top;
    background-repeat: repeat-x;
    border-bottom: 1px solid #D7CF9E;
    border-left: 1px solid #E4DDB4;
    border-right: 1px solid #DCD4A4;
    color: black;
    font-size: 11px;
    font-weight: bold;
    margin: 0;
    padding: 2px 10px 5px;
}

#header h1 {
    font-size: 11px;
    overflow: hidden;
}

h1 {
    margin: 0;
    padding: 0;
}

#pageBody {
    float: right;
    font-size: 11px; /*margin-left: 12px;*/
/*margin-right: 15px;*/
    text-align: left;
    width: 850px;
}
CSS

file 'app/assets/stylesheets/applications.css', <<-CSS
#container {
    width: 100%;
    font-family: tahoma, verdana, arial, sans-serif, Lucida Sans;
    font-size: 11px;
}

#col1, #col2, #col3 {
    float: left;
    padding-right: 20px;
}

#insightPopup {
    position: fixed;
    z-index: 1;
    left: 685px;
    top: 200px;
    width: 550px;
    height: 300px;
    border: blue solid 2px;
    padding-left: 20px;
    background-color: khaki;
    overflow-y: scroll;
}

a:hover img {
    border: 0px;
    cursor: pointer
}

#notice {
    background-color: #A4E7A0;
    border: 1px solid #26722D;
}

#error {
    background-color: #F0A8A8;
    border: 1px solid #900;
}

#notice, #error {
    width: 90%;
    margin: 0 auto 10px auto;
    padding: 5px;
}

#notice p, #error p {
    margin-left: 20px;
    padding: 0;
    font-size: .75em;
    color: #000;
}

#notice a, #error a {
    text-decoration: none;
    padding: 0 3px;
}

#notice a {
    border: 1px solid #26722D;
    color: #26722D;
}

#error a {
    border: 1px solid #900;
    color: #900;
}

#notice a:hover, #error a:hover {
    color: #333;
    border: 1px solid #333;
}

.inactive {
    color: #999999;
}

.inactive > a {
    display: none;
}

ul.hmenu {
    list-style: none;
    margin: 0 0 2em;
    padding: 0;
}

ul.hmenu li {
    display: inline;
}

.div_btn {
    background: none repeat scroll 0 0 #36638E;
    color: #FFFFFF;
    display: inline;
    padding: 3px 8px;
}

CSS

['header_divider.gif', 'header_yellow.gif'].each do |img|

  download_file "https://github.com/stulentsev/rails-templates/raw/master/assets/#{img}", "app/assets/images/#{img}"
end

