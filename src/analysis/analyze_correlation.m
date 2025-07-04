function analyze_correlation(original_image_roi_pixels, encrypted_image_roi_pixels, num_pixel_pairs, output_folder, base_filename)
% analyze_correlation: Calculates and displays correlation of adjacent pixels
%                      for ROI pixels of original and encrypted images.
%
% Args:
%   original_image_roi_pixels (cell array): {R, G, B} 1D arrays of uint8 pixel values (original ROI).
%   encrypted_image_roi_pixels (cell array): {R, G, B} 1D arrays of uint8 pixel values (encrypted ROI).
%                                         NOTE: For correlation analysis, we typically need the 2D structure
%                                         of the ROI to find adjacent pixels. This function will need to
%                                         reconstruct temporary 2D ROI patches or receive 2D image ROIs.
%                                         For simplicity, this function will assume inputs are full images
%                                         and ROI_info will be used to extract pixels for analysis,
%                                         OR that the input _roi_pixels are actually structured (e.g. cell of matrices).
%                                         Revising to accept image matrices and ROI_info.
%
%   Instead of *_roi_pixels, let's take:
%   original_image (HxWx3 uint8): Full original image.
%   encrypted_image (HxWx3 uint8): Full encrypted image.
%   ROI_info (struct array): From psrd.m, defining ROIs.
%   index_seg_shuffled (vector): Order of patches (though for correlation, order might not matter as much as spatial adjacency).
%
%   num_pixel_pairs (int): Number of random pixel pairs to select for plotting.
%   output_folder (str): Folder to save the plots.
%   base_filename (str): Base name for saved plot files.

    if nargin < 4
        output_folder = '.';
        base_filename = 'corr_analysis';
    end
    if nargin < 3 || isempty(num_pixel_pairs)
        num_pixel_pairs = 1000; % Default number of pairs for scatter plot
    end
    if ~exist(output_folder, 'dir'), mkdir(output_folder); end

    % --- Redefine inputs for clarity with new plan ---
    % This function will be called with:
    % analyze_correlation(original_image_matrix, encrypted_image_matrix,
    %                     ROI_info_struct, index_seg_shuffled_order_not_used_here,
    %                     num_pixel_pairs, output_folder, base_filename)

    original_image_matrix = original_image_roi_pixels; % Argument re-purposed
    encrypted_image_matrix = encrypted_image_roi_pixels; % Argument re-purposed
    ROI_info_struct = num_pixel_pairs; % Argument re-purposed
    % num_pixel_pairs_arg = output_folder; % Argument re-purposed
    % output_folder_arg = base_filename; % Argument re-purposed
    % base_filename_arg = ???; % Need to adjust function signature in plan or here.

    % Let's stick to the original signature for now and assume the caller prepares
    % the pixel data appropriately. If *_roi_pixels are 1D arrays, we cannot
    % compute spatial correlations. The helper get_roi_pixels_from_image in analyze_histogram.m
    % also produces 1D arrays.
    %
    % CONCLUSION: This function MUST operate on 2D image data for ROIs.
    % It's better to pass the full images and ROI_info.
    % The plan for performance analysis module implies this.

    % Corrected arguments based on likely usage:
    % analyze_correlation(image_matrix_orig, image_matrix_enc, ROI_info, num_pairs, out_fold, base_name)

    image_matrix_original = original_image_roi_pixels; % Renaming for clarity
    image_matrix_encrypted = encrypted_image_roi_pixels; % Renaming
    ROI_info = num_pixel_pairs; % This is now ROI_info struct
    actual_num_pixel_pairs = output_folder; % This is actual num_pixel_pairs
    actual_output_folder = base_filename; % This is actual output_folder
    actual_base_filename = [actual_output_folder, '_placeholder_name']; % Need one more arg or combine

    % This signature is getting messy due to misinterpretation. Let's define a clean one.
    % analyze_correlation(img_orig, img_enc, rois, num_pairs_plot, out_dir, file_base)

    if nargin < 6 % Corrected number of expected arguments
         error('analyze_correlation needs at least 6 arguments: img_orig, img_enc, ROI_info, num_pixel_pairs, output_folder, base_filename');
    end
    % Unpacking arguments based on the corrected understanding:
    img_orig_param = original_image_roi_pixels;
    img_enc_param = encrypted_image_roi_pixels;
    ROI_info_param = num_pixel_pairs; % This is the ROI_info struct
    num_pixel_pairs_plot = output_folder;
    output_folder_param = base_filename;
    base_filename_param = [output_folder_param(1:min(3,length(output_folder_param))), '_corr_plot']; % Temp name
    if(nargin > 5) % A 6th argument was passed for base_filename
        base_filename_param = arguments{6};
    end


    fprintf('Starting Correlation Analysis...\n');

    images_to_analyze = {img_orig_param, img_enc_param};
    image_titles = {'Original Image ROI', 'Encrypted Image ROI'};
    plot_suffixes = {'original', 'encrypted'};

    correlation_results = struct();

    for i = 1:length(images_to_analyze)
        current_image_matrix = images_to_analyze{i};
        current_title_prefix = image_titles{i};
        correlation_results.(plot_suffixes{i}) = struct('horizontal',[],'vertical',[],'diagonal',[]);

        if isempty(current_image_matrix)
            fprintf('Image data for "%s" is empty. Skipping correlation analysis.\n', current_title_prefix);
            continue;
        end

        % Collect all valid pixel coordinates from all ROIs
        all_roi_coords_r = [];
        all_roi_coords_c = [];

        for k_roi = 1:length(ROI_info_param)
            if ROI_info_param(k_roi).has_roi && ~isempty(ROI_info_param(k_roi).roi_rect)
                rect = ROI_info_param(k_roi).roi_rect; % x,y,w,h
                min_c = rect(1); min_r = rect(2);
                w = rect(3); h = rect(4);

                % Create a grid of coordinates for this ROI
                [cols_grid, rows_grid] = meshgrid(min_c : min_c+w-1, min_r : min_r+h-1);
                all_roi_coords_r = [all_roi_coords_r; rows_grid(:)];
                all_roi_coords_c = [all_roi_coords_c; cols_grid(:)];
            end
        end

        if isempty(all_roi_coords_r)
            fprintf('No valid ROI pixels found for %s. Skipping.\n', current_title_prefix);
            continue;
        end

        % Randomly select starting pixels for pairs, ensuring neighbors are within bounds
        num_total_roi_pixels = length(all_roi_coords_r);
        if num_total_roi_pixels < 2 % Need at least 2 pixels for a pair
            fprintf('Not enough ROI pixels for correlation in %s. Skipping.\n', current_title_prefix);
            continue;
        end

        % --- Coefficients calculation (using ALL valid adjacent pairs in ROIs) ---
        coeffs_h = zeros(1,3); coeffs_v = zeros(1,3); coeffs_d = zeros(1,3);

        for channel = 1:3 % R, G, B
            img_ch = current_image_matrix(:,:,channel);

            % Horizontal
            x_h = []; y_h = [];
            for p_idx = 1:num_total_roi_pixels
                r = all_roi_coords_r(p_idx); c = all_roi_coords_c(p_idx);
                if c+1 <= size(img_ch,2) && is_coord_in_any_roi(r, c+1, ROI_info_param)
                    x_h = [x_h, img_ch(r,c)];
                    y_h = [y_h, img_ch(r,c+1)];
                end
            end
            if length(x_h) > 1, coeffs_h(channel) = corrcoef_calc(x_h, y_h); else, coeffs_h(channel)=NaN; end

            % Vertical
            x_v = []; y_v = [];
            for p_idx = 1:num_total_roi_pixels
                r = all_roi_coords_r(p_idx); c = all_roi_coords_c(p_idx);
                if r+1 <= size(img_ch,1) && is_coord_in_any_roi(r+1, c, ROI_info_param)
                    x_v = [x_v, img_ch(r,c)];
                    y_v = [y_v, img_ch(r+1,c)];
                end
            end
            if length(x_v) > 1, coeffs_v(channel) = corrcoef_calc(x_v, y_v); else, coeffs_v(channel)=NaN; end

            % Diagonal (top-left to bottom-right)
            x_d = []; y_d = [];
            for p_idx = 1:num_total_roi_pixels
                r = all_roi_coords_r(p_idx); c = all_roi_coords_c(p_idx);
                if r+1 <= size(img_ch,1) && c+1 <= size(img_ch,2) && is_coord_in_any_roi(r+1, c+1, ROI_info_param)
                    x_d = [x_d, img_ch(r,c)];
                    y_d = [y_d, img_ch(r+1,c+1)];
                end
            end
            if length(x_d) > 1, coeffs_d(channel) = corrcoef_calc(x_d, y_d); else, coeffs_d(channel)=NaN; end
        end
        correlation_results.(plot_suffixes{i}).horizontal = coeffs_h;
        correlation_results.(plot_suffixes{i}).vertical = coeffs_v;
        correlation_results.(plot_suffixes{i}).diagonal = coeffs_d;
        fprintf('Correlation coefficients for %s (R,G,B):\n', current_title_prefix);
        fprintf('  Horizontal: %.4f, %.4f, %.4f\n', coeffs_h(1), coeffs_h(2), coeffs_h(3));
        fprintf('  Vertical:   %.4f, %.4f, %.4f\n', coeffs_v(1), coeffs_v(2), coeffs_v(3));
        fprintf('  Diagonal:   %.4f, %.4f, %.4f\n', coeffs_d(1), coeffs_d(2), coeffs_d(3));

        % --- Scatter Plots (using a subset of pairs for speed) ---
        num_pairs_to_select = min(actual_num_pixel_pairs, num_total_roi_pixels);
        rand_indices = randperm(num_total_roi_pixels, num_pairs_to_select);

        selected_coords_r = all_roi_coords_r(rand_indices);
        selected_coords_c = all_roi_coords_c(rand_indices);

        plot_data = struct('h',{{[],[],[]},{[],[],[]}}, 'v',{{[],[],[]},{[],[],[]}}, 'd',{{[],[],[]},{[],[],[]}});
        % {channel}{x or y}

        for k_pair = 1:num_pairs_to_select
            r = selected_coords_r(k_pair);
            c = selected_coords_c(k_pair);

            % Horizontal
            if c+1 <= size(current_image_matrix,2) && is_coord_in_any_roi(r, c+1, ROI_info_param)
                for ch=1:3, plot_data.h{ch}{1}=[plot_data.h{ch}{1}, current_image_matrix(r,c,ch)]; plot_data.h{ch}{2}=[plot_data.h{ch}{2}, current_image_matrix(r,c+1,ch)]; end
            end
            % Vertical
            if r+1 <= size(current_image_matrix,1) && is_coord_in_any_roi(r+1, c, ROI_info_param)
                 for ch=1:3, plot_data.v{ch}{1}=[plot_data.v{ch}{1}, current_image_matrix(r,c,ch)]; plot_data.v{ch}{2}=[plot_data.v{ch}{2}, current_image_matrix(r+1,c,ch)]; end
            end
            % Diagonal
            if r+1 <= size(current_image_matrix,1) && c+1 <= size(current_image_matrix,2) && is_coord_in_any_roi(r+1, c+1, ROI_info_param)
                 for ch=1:3, plot_data.d{ch}{1}=[plot_data.d{ch}{1}, current_image_matrix(r,c,ch)]; plot_data.d{ch}{2}=[plot_data.d{ch}{2}, current_image_matrix(r+1,c+1,ch)]; end
            end
        end

        h_fig_corr = figure('Name', ['Correlation Scatter Plots - ', current_title_prefix], 'Visible', 'off', 'Position', [100, 100, 1200, 400]);
        plot_titles = {'Horizontal', 'Vertical', 'Diagonal'};
        plot_fields = {'h', 'v', 'd'};
        channel_colors = {[1 0 0], [0 1 0], [0 0 1]}; % R, G, B

        for j_plot = 1:3 % h, v, d
            subplot(1, 3, j_plot);
            hold on;
            for ch_plot = 1:3 % R, G, B channels
                if ~isempty(plot_data.(plot_fields{j_plot}){ch_plot}{1})
                    scatter(plot_data.(plot_fields{j_plot}){ch_plot}{1}, ...
                            plot_data.(plot_fields{j_plot}){ch_plot}{2}, ...
                            5, 'filled', 'MarkerFaceColor', channel_colors{ch_plot}, 'MarkerFaceAlpha', 0.5);
                end
            end
            hold off;
            axis([0 255 0 255]); axis square; grid on;
            xlabel('Pixel Value (P1)'); ylabel('Pixel Value (P2)');
            title(plot_titles{j_plot});
            if j_plot == 1, legend({'Red Ch', 'Green Ch', 'Blue Ch'}, 'Location', 'northwest'); end
        end
        sgtitle([current_title_prefix, ' - Adjacent Pixel Correlation (',num2str(num_pairs_to_select),' random pairs from ROI)']);

        try
            saveas(h_fig_corr, fullfile(output_folder_param, [actual_base_filename, '_scatter_', plot_suffixes{i}, '.png']));
        catch ME_save
             fprintf('Could not save correlation scatter plot for %s: %s\n', current_title_prefix, ME_save.message);
        end
        close(h_fig_corr);
    end

    assignin('base', 'correlation_analysis_results', correlation_results);
    fprintf('Correlation analysis complete. Results struct stored in workspace variable "correlation_analysis_results".\n');
    fprintf('Scatter plots saved to folder: %s\n', output_folder_param);

end

function is_in = is_coord_in_any_roi(r_coord, c_coord, ROI_info_struct)
% Checks if a given coordinate (r,c) falls within any defined ROI rectangle.
    is_in = false;
    for k = 1:length(ROI_info_struct)
        if ROI_info_struct(k).has_roi && ~isempty(ROI_info_struct(k).roi_rect)
            rect = ROI_info_struct(k).roi_rect; % x,y,w,h (min_c, min_r, width, height)
            if r_coord >= rect(2) && r_coord < (rect(2)+rect(4)) && ...
               c_coord >= rect(1) && c_coord < (rect(1)+rect(3))
                is_in = true;
                return;
            end
        end
    end
end

function c = corrcoef_calc(x,y)
% Calculate single correlation coefficient if inputs are valid
    if isempty(x) || isempty(y) || length(x) < 2 || length(y) < 2 || length(x) ~= length(y)
        c = NaN;
        return;
    end
    % Check for constant series, which also result in NaN for corrcoef
    if all(x == x(1)) || all(y == y(1))
        c = NaN; % Or 0, depending on desired interpretation for constant data
        return;
    end
    temp_c = corrcoef(double(x), double(y));
    c = temp_c(1,2);
end

% % Example Usage:
% if 0
%     clc; clearvars; close all;
%     % Create dummy images and ROI_info
%     img_h = 100; img_w = 100;
%     dummy_orig_img = uint8(randi([0,255], img_h, img_w, 3));
%     dummy_enc_img = uint8(randi([0,255], img_h, img_w, 3)); % Encrypted should be decorrelated
%
%     % Define some ROIs
%     roi_info_test = repmat(struct('patch_index',0,'has_roi',false,'roi_rect',[]),1,1);
%     roi_info_test(1).patch_index = 1;
%     roi_info_test(1).has_roi = true;
%     roi_info_test(1).roi_rect = [10, 10, 30, 30]; % ROI 1: [x,y,w,h]
%
%     roi_info_test(2).patch_index = 2; % Need to make sure this is handled if ROI_info is not dense
%     roi_info_test(2).has_roi = true;
%     roi_info_test(2).roi_rect = [50, 50, 25, 25]; % ROI 2
%
%     % Correct way to initialize ROI_info struct array for length
%     num_total_patches = 4; % Example for a 2x2 PSRD grid
%     roi_info_test_corr = repmat(struct('patch_index',0,'has_roi',false,'roi_rect',[]),1,num_total_patches);
%     roi_info_test_corr(1).patch_index = 1; % Patch 1 (top-left)
%     roi_info_test_corr(1).has_roi = true;
%     roi_info_test_corr(1).roi_rect = [10, 10, 30, 30];
%     roi_info_test_corr(4).patch_index = 4; % Patch 4 (bottom-right in 2x2)
%     roi_info_test_corr(4).has_roi = true;
%     roi_info_test_corr(4).roi_rect = [50, 50, 25, 25];
%
%
%     num_pairs_for_plot = 500;
%     output_dir_corr = 'temp_results_corr';
%     base_fname_corr = 'dummy_img';
%
%     % analyze_correlation(img_orig, img_enc, rois, num_pairs_plot, out_dir, file_base)
%     analyze_correlation(dummy_orig_img, dummy_enc_img, roi_info_test_corr, num_pairs_for_plot, output_dir_corr, base_fname_corr);
%
%     fprintf('Check folder "%s" for correlation plots and workspace for results struct.\n', output_dir_corr);
%     % load('correlation_analysis_results.mat'); % If saved to .mat
%     % disp(correlation_analysis_results);
%
%     % rmdir(output_dir_corr, 's'); % Clean up
% end
