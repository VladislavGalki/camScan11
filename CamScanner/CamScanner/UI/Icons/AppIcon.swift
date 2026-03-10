import SwiftUI

public enum AppIcon: String, CaseIterable {

    // MARK: - Arrows
    case arrowForward = "arrow_forward"
    case arrowBack = "arrow_back"
    case arrowDown = "arrow_down"
    case arrowUp = "arrow_up"

    // MARK: - Stroke
    case strokeArrowBack = "stroke_arrow_back"
    case home = "home"
    case plus = "plus"
    case search = "search"
    case star = "star"
    case dots = "dots"
    case backForward = "back_forward"
    case close = "close"
    case grid = "grid"
    case flash = "flash"
    case gridOff = "grid_off"
    case flashOff = "flash_off"
    case flashAuto = "flash_auto"
    case link = "link"
    case share = "share"
    case page_plus = "page++"
    case crop = "crop"
    case rotate = "rotate"
    case signature = "signature"
    case trash = "trash"
    case back = "back"
    case forward = "forward"
    case check = "check"
    case expand = "expand"
    case autoCrop = "autocrop"
    case eye = "eye"
    case eye_splash = "eye_splash"
    case files = "files"
    case settings = "settings"
    case tools = "tools"
    case grid2 = "grid2"
    case list = "list"
    case folder = "folder"
    case check_circle = "check_circle"
    case lock = "lock"
    case edit = "edit"
    case move = "move"
    case merge = "merge"
    
    // MARK: - Fill
    case homeFill = "home_fill"
    case settingsFill = "settings_fill"
    case toolsFill = "tools_fill"
    case fileFill = "file_fill"
    case filesFill = "files_fill"
    case starFill = "star_fill"
    case flashFill = "flash_fill"
    case closeFill = "close_fill"
    case lock_fill = "lock_fill"
    
    // MARK: - Outline
    case addCircle = "add_circle"
    
    // MARK: - Images
    case recognizeImage = "recognize_image"
    case addTextImage = "addText_image"
    case eraseImage = "erase_image"
    case translateImage = "translate_image"
    case signatureImage = "signature_image"
    case watermarkImage = "watermark_image"
    case cloudImage = "cloud_image"
    case passportImage = "passport_image"
    case pdfImage = "pdf_image"
    case jpgImage = "jpg_image"
    case docImage = "doc_image"
    case txtImage = "txt_image"
    case xlsImage = "xls_image"
    case pptImage = "ppt_image"
    case appMiniLogoImage = "appMiniLogo_image"
    case check_image = "check_image"
    case empty_check_image = "empty_check_image"
    case rect_separator_image = "rect_separator_image"
    case filesEmpty_image = "filesEmpty_Image"
    case folder_image = "folder_image"
    case folder_small_image = "folder_small_image"
    case lock_image = "lock_image"
    case faceId_image = "faceId_image"
    case empty_seatch_image = "empty_seatch_image"
    case empty_folder_image = "empty_folder_image"
}

public extension Image {
    init(appIcon: AppIcon) {
        self.init(appIcon.rawValue)
    }
}
