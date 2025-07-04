function analyze_histogram(original_image_roi_pixels, encrypted_image_roi_pixels, output_folder, base_filename)
% analyze_histogram: Calculates and displays histograms for ROI pixels
%                    of original and encrypted images.
%
% Args:
%   original_image_roi_pixels (cell array): Cell array {R, G, B} where each cell
%                                           contains a 1D array of uint8 pixel values
%                                           from the original image's ROIs.
%   encrypted_image_roi_pixels (cell array): Cell array {R, G, B} for the
%                                            encrypted image's ROIs.
%   output_folder (str): Folder to save the histogram plots.
%   base_filename (str): Base name for the saved plot file.

    if nargin < 3
        output_folder = '.'; % Default to current folder
        base_filename = 'hist_analysis';
    end
    if ~exist(output_folder, 'dir'), mkdir(output_folder); end

    titles = {'Original ROI Pixels', 'Encrypted ROI Pixels'};
    pixel_data_sources = {original_image_roi_pixels, encrypted_image_roi_pixels};
    colors = {'red', 'green', 'blue'};
    plot_suffixes = {'original_roi', 'encrypted_roi'};

    for i = 1:length(pixel_data_sources)
        current_pixels_cell = pixel_data_sources{i};
        if isempty(current_pixels_cell) || all(cellfun('isempty', current_pixels_cell))
            fprintf('Pixel data for "%s" is empty. Skipping histogram.\n', titles{i});
            continue;
        end

        h_fig = figure('Name', ['Histogram - ', titles{i}], 'Visible', 'off');

        % Check if data is already separated into R,G,B or needs to be
        % Assuming current_pixels_cell is { [R_pixels], [G_pixels], [B_pixels] }
        % If it were a full image matrix, we'd extract ROIs first.
        % The input arguments are defined as cell arrays of already extracted ROI pixels.

        if ~iscell(current_pixels_cell) || length(current_pixels_cell) ~= 3
            warning('Expected pixel data as a cell array of 3 channels for %s. Skipping.', titles{i});
            continue;
        end

        for channel = 1:3 % R, G, B
            subplot(1, 3, channel);
            if ~isempty(current_pixels_cell{channel})
                histogram(current_pixels_cell{channel}, 0:255, 'FaceColor', colors{channel}, 'EdgeColor', 'none');
                xlim([0 255]);
                ylim_curr = ylim;
                if ylim_curr(2) == 0, ylim([0 1]); else, ylim([0 ylim_curr(2)*1.1]); end % Ensure some y-axis height
                grid on;
            else
                plot(0,0); % Empty plot if no data for this channel
                text(0.5,0.5, 'No Data', 'HorizontalAlignment', 'center');
            end
            title(['Channel ', colors{channel}]);
        end
        sgtitle([titles{i}, ' Histograms']);

        try
            saveas(h_fig, fullfile(output_folder, [base_filename, '_', plot_suffixes{i}, '.png']));
        catch ME_save
            fprintf('Could not save histogram for %s: %s\n', titles{i}, ME_save.message);
        end
        close(h_fig);
    end
    fprintf('Histogram analysis plots saved to folder: %s\n', output_folder);
end

% Helper function to extract ROI pixels from an image given ROI_info
% This might be called before analyze_histogram if input is full images + ROI_info
function roi_pixels_cell = get_roi_pixels_from_image(image_matrix, ROI_info_struct, index_seg_shuffled_order)
% Args:
%   image_matrix (HxWx3 uint8): The image.
%   ROI_info_struct (struct array): From psrd.m.
%   index_seg_shuffled_order (vector): Order of patches.
% Returns:
%   roi_pixels_cell: Cell array {R_pixels, G_pixels, B_pixels}

    if isempty(ROI_info_struct) || isempty(index_seg_shuffled_order) || isempty(image_matrix)
        roi_pixels_cell = {[], [], []};
        return;
    end

    total_pixels_in_rois = 0;
    for k_patch = 1:length(ROI_info_struct)
        if ROI_info_struct(k_patch).has_roi && ~isempty(ROI_info_struct(k_patch).roi_rect)
            rect = ROI_info_struct(k_patch).roi_rect;
            total_pixels_in_rois = total_pixels_in_rois + rect(3)*rect(4);
        end
    end

    if total_pixels_in_rois == 0
        roi_pixels_cell = {[], [], []};
        return;
    end

    R_all = zeros(1, total_pixels_in_rois, 'uint8');
    G_all = zeros(1, total_pixels_in_rois, 'uint8');
    B_all = zeros(1, total_pixels_in_rois, 'uint8');
    current_pixel_idx = 0;

    for k_shuffled = 1:length(index_seg_shuffled_order)
        patch_original_idx = index_seg_shuffled_order(k_shuffled);

        % Find the ROI_info for this original patch index
        info_entry = [];
        for r_info_idx = 1:length(ROI_info_struct)
            if ROI_info_struct(r_info_idx).patch_index == patch_original_idx
                info_entry = ROI_info_struct(r_info_idx);
                break;
            end
        end

        if ~isempty(info_entry) && info_entry.has_roi && ~isempty(info_entry.roi_rect)
            rect = info_entry.roi_rect; % x,y,w,h
            min_c = rect(1); min_r = rect(2);
            max_c = rect(1)+rect(3)-1; max_r = rect(2)+rect(4)-1;

            for r = min_r:max_r
                for c = min_c:max_c
                    current_pixel_idx = current_pixel_idx + 1;
                    R_all(current_pixel_idx) = image_matrix(r,c,1);
                    G_all(current_pixel_idx) = image_matrix(r,c,2);
                    B_all(current_pixel_idx) = image_matrix(r,c,3);
                end
            end
        end
    end
    roi_pixels_cell = {R_all(1:current_pixel_idx), G_all(1:current_pixel_idx), B_all(1:current_pixel_idx)};
end

% % Example Usage:
% if 0
%     clc; clearvars; close all;
%     % Create dummy ROI pixel data
%     dummy_R_orig = uint8(randi([50, 100], 1, 1000));
%     dummy_G_orig = uint8(randi([80, 150], 1, 1000));
%     dummy_B_orig = uint8(randi([100, 200], 1, 1000));
%     original_roi_data = {dummy_R_orig, dummy_G_orig, dummy_B_orig};
%
%     dummy_R_enc = uint8(randi([0, 255], 1, 1000)); % Encrypted should be uniform
%     dummy_G_enc = uint8(randi([0, 255], 1, 1000));
%     dummy_B_enc = uint8(randi([0, 255], 1, 1000));
%     encrypted_roi_data = {dummy_R_enc, dummy_G_enc, dummy_B_enc};
%
%     output_dir = 'temp_results_hist';
%     analyze_histogram(original_roi_data, encrypted_roi_data, output_dir, 'dummy_image');
%     fprintf('Check folder "%s" for histogram plots.\n', output_dir);
%
%     % Example with get_roi_pixels_from_image
%     if exist('peppers.png', 'file')
%         img = imread('peppers.png');
%         % Dummy ROI_info (e.g., cover whole image as one ROI for test)
%         [h, w, ~] = size(img);
%         roi_info_test(1).patch_index = 1;
%         roi_info_test(1).has_roi = true;
%         roi_info_test(1).roi_rect = [1, 1, w, h]; % x,y,w,h
%         idx_shuffled_test = [1];
%
%         extracted_pixels = get_roi_pixels_from_image(img, roi_info_test, idx_shuffled_test);
%         analyze_histogram(extracted_pixels, [], output_dir, 'peppers_full_hist_test');
%         fprintf('Histogram for full peppers image (as ROI) generated.\n');
%     end
%
%     % rmdir(output_dir, 's'); % Clean up
% end
