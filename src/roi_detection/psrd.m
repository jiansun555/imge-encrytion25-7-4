function ROI_info = psrd(saliency_map_binary, N)
% psrd: Patch-based Salient Region Detection.
% Divides the saliency map into N x N patches and finds bounding boxes
% for salient regions within each patch.
%
% Args:
%   saliency_map_binary (logical matrix): Binary saliency map.
%   N (int): Number of patches to divide the image into (N x N grid). Default is 6.
%
% Returns:
%   ROI_info (struct array): An array of structs, one for each of the N*N patches.
%                            Each struct contains:
%                              - patch_index (int): Linear index of the patch (1 to N*N).
%                              - has_roi (logical): True if the patch contains salient pixels.
%                              - roi_rect (vector): [min_col, min_row, width, height] of the
%                                                 bounding box for salient regions in this patch.
%                                                 Empty if has_roi is false. Coordinates are
%                                                 relative to the original image.
%
% Note: The paper mentions "top-left and lower-right coordinates".
%       Matlab's regionprops uses [min_col, min_row, width, height] (BoundingBox).
%       We will store this format and can convert if needed.

    if nargin < 2 || isempty(N)
        N = 6; % Default number of patches per dimension
    end

    [img_height, img_width] = size(saliency_map_binary);

    patch_height = floor(img_height / N);
    patch_width = floor(img_width / N);

    % Initialize ROI_info structure
    num_patches = N * N;
    ROI_info = repmat(struct('patch_index', 0, 'has_roi', false, 'roi_rect', []), 1, num_patches);

    patch_idx_counter = 0;
    for i = 0:N-1 % Row index of patches
        for j = 0:N-1 % Column index of patches
            patch_idx_counter = patch_idx_counter + 1;
            ROI_info(patch_idx_counter).patch_index = patch_idx_counter;

            % Define patch boundaries
            row_start = i * patch_height + 1;
            row_end = (i + 1) * patch_height;
            col_start = j * patch_width + 1;
            col_end = (j + 1) * patch_width;

            % Adjust for last patch if image size is not perfectly divisible
            if i == N-1
                row_end = img_height;
            end
            if j == N-1
                col_end = img_width;
            end

            % Extract the current patch from the saliency map
            current_patch_saliency = saliency_map_binary(row_start:row_end, col_start:col_end);

            if any(current_patch_saliency(:)) % If there are salient pixels in this patch
                ROI_info(patch_idx_counter).has_roi = true;

                % Find coordinates of salient pixels within the patch
                [s_rows, s_cols] = find(current_patch_saliency);

                if ~isempty(s_rows)
                    % Calculate bounding box relative to the patch
                    min_s_row_patch = min(s_rows);
                    max_s_row_patch = max(s_rows);
                    min_s_col_patch = min(s_cols);
                    max_s_col_patch = max(s_cols);

                    % Convert patch-relative coordinates to original image coordinates
                    abs_min_col = col_start + min_s_col_patch - 1;
                    abs_min_row = row_start + min_s_row_patch - 1;
                    abs_max_col = col_start + max_s_col_patch - 1;
                    abs_max_row = row_start + max_s_row_patch - 1;

                    roi_w = abs_max_col - abs_min_col + 1;
                    roi_h = abs_max_row - abs_min_row + 1;

                    ROI_info(patch_idx_counter).roi_rect = [abs_min_col, abs_min_row, roi_w, roi_h];
                else
                    % Should not happen if any(current_patch_saliency(:)) is true, but as a safeguard
                    ROI_info(patch_idx_counter).has_roi = false;
                end
            else
                ROI_info(patch_idx_counter).has_roi = false;
                ROI_info(patch_idx_counter).roi_rect = [];
            end
        end
    end
end

% % Example Usage:
% if 0 % Set to 1 to run example
%     clc; clearvars; close all;
%
%     % Create a dummy saliency map
%     img_h = 240; img_w = 320;
%     dummy_saliency_map = false(img_h, img_w);
%     % Add some salient regions
%     dummy_saliency_map(50:100, 50:100) = true;   % A salient region in an early patch
%     dummy_saliency_map(150:200, 250:300) = true; % A salient region in a later patch
%
%     N_test = 4; % Test with 4x4 patches
%
%     roi_info_output = psrd(dummy_saliency_map, N_test);
%
%     fprintf('PSRD Test Results (N=%d):\n', N_test);
%     for k = 1:length(roi_info_output)
%         fprintf('Patch %d: Has ROI = %s', roi_info_output(k).patch_index, string(roi_info_output(k).has_roi));
%         if roi_info_output(k).has_roi
%             fprintf(', Rect = [%s]\n', num2str(roi_info_output(k).roi_rect));
%         else
%             fprintf('\n');
%         end
%     end
%
%     % Visualize the patches and detected ROIs
%     figure('Name', 'PSRD Test Visualization');
%     imshow(dummy_saliency_map);
%     title(sprintf('PSRD Test - Saliency Map with ROIs (N=%d)', N_test));
%     hold on;
%
%     patch_h_viz = floor(img_h / N_test);
%     patch_w_viz = floor(img_w / N_test);
%
%     % Draw patch grid
%     for i = 1:N_test-1
%         line([1 img_w], [i*patch_h_viz i*patch_h_viz], 'Color', 'blue', 'LineStyle', '--');
%         line([i*patch_w_viz i*patch_w_viz], [1 img_h], 'Color', 'blue', 'LineStyle', '--');
%     end
%
%     % Draw detected ROIs
%     for k = 1:length(roi_info_output)
%         if roi_info_output(k).has_roi
%             rectangle('Position', roi_info_output(k).roi_rect, 'EdgeColor', 'red', 'LineWidth', 1.5);
%         end
%     end
%     hold off;
% end
