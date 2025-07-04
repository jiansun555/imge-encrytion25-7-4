# Expert Systems With Applications 279 (2025) 127404

**Contents lists available at ScienceDirect**

# Expert Systems With Applications

**journal homepage: www.elsevier.com/locate/eswa**

---

# Semantically enhanced selective image encryption scheme with parallel computing

**Buyu Liu a, Wei Song a,*, Mingyi Zheng a, Chong Fu a,b, Junxin Chen c, Xingwei Wang a**

a School of Computer Science and Engineering, Northeastern University, Shenyang 110819, China
b Engineering Research Center of Security Technology of Complex Network System, Ministry of Education, China
c School of Software, Dalian University of Technology, Dalian 116621, China

---

## ARTICLE INFO

**Keywords:**
Image ROI encryption
Salient object detection
Chaos
Simultaneous permutation-diffusion
Parallel computing

---

## ABSTRACT

Recently, an increasing number of ROI (regions of interest) encryption algorithms have been proposed to efficiently encrypt the sensitive regions of image. Due to the powerful feature extraction capabilities of deep learning (DP), many DP-based object detection models have been increasingly applied to ROI encryption. However, some models with a large number of parameters are inefficient and not suitable for real-time detection, and the detected ROI often include some redundant regions. Moreover, the following encryption operations are always in serial manner, leaving room for improvement. To address these issues, we present a semantically enhanced selective image encryption scheme with parallel computing. The deep salient object detection (SOD) model is first lightweighted to improve detection efficiency. Then, the sensitive region is cropped based on the boundary information from the output saliency map, resulting in an ROI that removes redundant regions without revealing sensitive object information. In encryption stage, the three color channels of each pixel are assigned to a group and encrypted in parallel to further improve the efficiency. Furthermore, to enhance the practicality, we embedded the side information of the ROI into the image, eliminating the need to separately distribute the image and the corresponding side information. Finally, we carry out security and efficiency analyses, and the results demonstrate that the proposed encryption scheme can enable efficient and secure detection of sensitive regions, along with corresponding encryption protection.

---

## 1. Introduction

With the rapid development of the Internet, people are sharing various images on the internet every day. However, without necessary protection, hackers can easily obtain people's private information and sell them to criminals. In order to guarantee information security, many image cryptosystems have been proposed.

With image generation/capture devices becoming increasingly powerful and the increase in network bandwidth, the use of large-capacity and high-resolution images has become increasingly frequent. Conventional encryption algorithms such as DES, AES, RSA and some existing image encryption schemes (Hu et al., 2024; Kocak et al., 2024; Lai et al., 2022; Peng et al., 2024; Song et al., 2023; Song, Fu, Zheng, et al., 2024; Zhang et al., 2023; Zhou et al., 2024) can enable the protection of image data, but have some operations on non-sensitive regions. The main reason is that many methods do not take image semantic features into account and often encrypt the entire image, leading to reduced efficiency.

As a matter of fact, not all regions in image are equally sensitive, therefore, digital images can be protected by encrypting sensitive regions which are called Regions of Interest (ROI). Table 1 lists some recent ROI detection methods. In Singh, Devi, et al. (2022), ROI were detected manually and in Balasamy and Suganyadevi (2021), Cai et al. (2024), Kiran and Parameshachari (2022), Kiran et al. (2020), Liu, Zhang, et al. (2020), Murali et al. (2023), Ramacharya et al. (2023), Su et al. (2023), some machine learning methods are exploited to detect the sensitive regions of the images. However, compared with the increasingly developed deep learning-based feature attraction approaches (Zhang et al., 2025; Zou et al., 2025), these conventional ROI detection schemes tend to have big limitations in speed and accuracy. Singh et al. (2024), Wang et al. (2023), Wang, Liu, et al. (2022), Wang et al. (2024) exploited instance segmentation to accurately locate sensitive regions of the image, yet they ignored the hiding of edge information, thus causing the risk of information leakage. Due to the validity of YOLO in object detection, (Asgari-Chenaghlu et al., 2021;

* Corresponding author.
E-mail addresses: 2301807@stu.neu.edu.cn (B. Liu), songwei@mail.neu.edu.cn (W. Song), 2401802@stu.neu.edu.cn (M. Zheng), fuchong@mail.neu.edu.cn (C. Fu), junxinchen@ieee.org (J. Chen), wangxw@mail.neu.edu.cn (X. Wang).

https://doi.org/10.1016/j.eswa.2025.127404
Received 13 December 2024; Received in revised form 13 March 2025; Accepted 22 March 2025
Available online 4 April 2025
0957-4174/© 2025 Elsevier Ltd. All rights are reserved, including those for text and data mining, AI training, and similar technologies.

---

[Table 1: Several ROI detection methods and their drawbacks.]
| Refs. | ROI detection methods | Limitations |
| :--- | :--- | :--- |
| Singh, Devi, et al. (2022) | Manual segmentation | Lack of real-time considerations. |
| Liu, Zhang, et al. (2020) | HOG + SVM | |
| Murali et al. (2023) | Orthogonal polynomial transformation | Limited feature extraction capabilities. |
| Su et al. (2023) | Multilayer cellular automata saliency detection | |
| Ramacharya et al. (2023) | Fuzzy rules | |
| Balasamy and Suganyadevi (2021) | KOS + VOS | |
| Cai et al. (2024) | Active contour model | |
| Kiran et al. (2020) | Laplacian edge detection operator | |
| Kiran and Parameshachari (2022) | PSPNet + Faster-RCNN | Redundant category categorization. |
| Wang, Liu, et al. (2022) | UNet3+ | Edge information leakage |
| Singh et al. (2024) | Mask RCNN | Redundant category categorization and edge information leakage. |
| Wang et al. (2023, 2024) | YOLOv3 + UNet | |
| Chen and Yang (2022) | | |
| Singh, Singh, et al. (2022) | | |
| Sheela and Suresh (2024) | YOLO series of algorithms | Redundant category categorization and large ROI. |
| Asgari-Chenaghlu et al. (2021) | | |
| Priyanka et al. (2024) | | |
| Zou et al. (2025) | | |
| Wang et al. (2025) | | |
| Song et al. (2022) | Modified YOLOV4 | |

Priyanka et al., 2024; Sheela & Suresh, 2024; Singh, Singh, et al., 2022; Wang et al., 2025; Zou et al., 2025) employed different versions of YOLO without optimization to detect the ROI, and Song et al. (2022) presented a modified YOLOv4 (Bochkovskiy et al., 2020) to guarantee that the bounding box can cover all regions of the target. However, whether it is instance segmentation or object detection, they classify targets when performing ROI detection, which is unnecessary in image encryption. Furthermore, the detected ROI in the above methods tend to be a large rectangular box, where many redundant windows are concluded, thus affecting the efficiency of the algorithm. Besides that, all of the above methods use a serial encryption approach during the encryption stage, which results in limited encryption efficiency. Moreover, most methods directly transmit side information related to the ROI without adequate protection, and also increase the cost of data distribution.

In summary, we identify the following issues in existing ROI methods that still need to be addressed.

*   The object detection stage should enhance protection for boundary regions while minimizing the inclusion of non-sensitive regions.
*   The efficiency of both object detection and encryption stages should be improved to enable real-time protection of sensitive regions.
*   ROI side information lacks protection, and transmitting it separately increases the distribution burden.

Having an intention to solve above problems, we present a novel and efficient algorithm for protecting image ROI. In object detection stage, a novel Patch-based Salient Region Detection (PSRD) method is introduced to optimize the detected sensitive regions. Here, we use deep-learning based salient object detection (SOD) to identify regions instead of object segmentation and detection, as it detects salient regions without categorizing the objects. It should be noted that most existing deep-SOD models (Pang et al., 2020; Qin et al., 2020, 2019; Wu et al., 2019; Zhao et al., 2020) tend to choose VGGs (Simonyan & Zisserman, 2014) or ResNets (He et al., 2015) as backbone, which contains convolutional layers that have enormous parameters, thus making these networks hard to deployed on device that has limited memory and computation resources. To improve the efficiency and practicality, we employ MobileNetV2-based (Sandler et al., 2018) lightweight Extremely-Downsampled Network (EDN-lite) (Wu, Liu, Zhang, et al., 2022) to efficiently detect the salient regions. The reason is that lightweighted EDN pays attention on low/high-level features learning at the same time, and it has higher detection accuracy and compared with some other methods while having fewer parameters. Specifically, the detected salient map is divided into multiple patches averagely. If there is a salient region in one patch, then the region is covered by a bounding box, which is determined by the boundary of detected salient region. In this way, we reduce the redundant data to be encrypted and the sensitive information in edge regions is well-protected in the subsequent encryption process.

In the encryption stage, the intrinsic properties of chaotic system, such as high sensitivity to initial conditions and good pseudo-randomness, make it well suited to cryptographic algorithms (Hua et al., 2020, 2021; Zhou et al., 2023). Here, we present a parallel chaos-based encryption method for fast encryption. For each pixel, its three 8-bit sub-pixel is randomly assigned to a new sequence, which is determined by a logistic map, and after assignment, the three pixel sequences are encrypted in parallel by an improved multi-dimensional hyperchaotic system (Wei & Li, 2022).

To ensure comprehensive protection and avoid the hassle of additional distribution, we aim to transmit all confidential data in a single transfer. Therefore, we employ reversible steganography to embed the ROI information into the ciphered image. Here, a reversible data hiding scheme based on the images texture (Jia et al., 2019) is used to hide the side information of the ROI inside the encrypted image. Here, ROI side information contains the number and the coordinate information of the ROI in each patch. Experimental results and security analyses demonstrate that our scheme outperforms state-of-the-art encryption algorithms on encryption efficiency and practicability.

Compared with existing schemes, the contributions of our scheme are summarized as follows,

*   In ROI encryption, the proposed PSRD first integrates lightweight ROI detection with patch-level optimization, improving detection efficiency.
*   The three color channels of ROI are encrypted in parallel, thus improving the efficiency.
*   Steganographic protection of ROI side information enhances the security and practicality.

The rest of this article is structured as follows. In Section 2, we introduce deep learning-based SOD, LICC hyperchaotic system and a reversible data hiding method. Our ROI detection scheme and the parallel image encryption algorithm is presented in Section 3. Experimental results and corresponding security analyses are reported in Section 4. And Section 5 is the conclusion and some discussion about the future work.

## 2. Related work

### 2.1. Deep learning-based SOD

SOD is a means used by Computer Vision (CV) to mimic the human visual system to identify important regions in a target image (Qin et al., 2019). With the wide application of Convolutional Neural Network (CNN) (Lecun et al., 1998) and Vision Transformer (ViT) (Dosovitskiy et al., 2020) in the field of computer vision, the deep learning-based SOD algorithms (Pang et al., 2020; Qin et al., 2020, 2019; Wu et al., 2019; Wu, Liu, Zhang, et al., 2022; Zhao et al., 2020) can distinguish the salient regions in the image and show superior performance over conventional methods (Hou & Zhang, 2007; Wang et al., 2011).

Given a three-channel color image I with dimensions of WXH, the trained SOD model f processes the image and outputs a binary salient map S, where S = f(I) ∈ {0,1}W×H. Specifically, in training dataset, every image I has a ground-truth map G(I) ∈ {0,1}W×H, and during the training process, the ultimate purpose is to find a model f that makes the destination between f(I) and G(I) to a minimum (Wang, Lai, et al., 2022). As one of the most popular and effective strategy used in SOD, multi-scale learning (MUL) method leverages low/high-level learning to better capture the fine-grained details of the object and locate the position of the salient regions, respectively (Hou et al., 2019; Liu, Han, et al., 2020). However, exiting MUL-based SOD methods still pay insufficient attention to high-level features (Liu et al., 2019; Zhao & Wu, 2019), to address this issue, EDN (Wu, Liu, Zhang, et al., 2022) used an Extremely Downsampled Block (EDB) to learn a global view of the image and achieved high accuracy with real-time speed in experiments. The architecture of the EDN is depicted in Fig. 1(a), in which scale-correlated pyramid convolution (SCPC) is constructed to effectively aggregate multi-level features from top to bottom, just as shown in Fig. 1(b). On the basis of EDN, we want to implement an ROI detection method that requires less computation resources and can quickly detect salient regions and complete sensitive regions protection. Here, the backbone of EDN is replaced by MobileNetv2 for realizing lightweight, just as depicted in Fig. 2. Furthermore, Conv3 × 3 block in EDB and Conv3 × 3 in SCPCs are replaced by inverted residual block and depth-wise separable 3 × 3 convolutions, respectively, thus making our algorithm much more practical.

### 2.2. Chaotic system

#### 2.2.1. LICC hyperchaotic system
As a multi-dimensional discrete hyperchaotic system, LICC (a combination of the Logistic map and the Iterative Chaotic Map with Infinite Collapse (ICMIC) through a closed-loop coupling method) is much more complex and uncertain than other chaotic system (Wei & Li, 2022), which is defined by
`x(i + 1) = cos[c(1/(a*y(i)*(1-y(i))) + 1/(a*z(i)*(1-z(i))) + b)] * sin[π/x(i)]`
`y(i + 1) = cos[c(1/(a*x(i)*(1-x(i))) + 1/(a*z(i)*(1-z(i))) + b)] * sin[π/y(i)]`
`z(i + 1) = cos[c(1/(a*x(i)*(1-x(i))) + 1/(a*y(i)*(1-y(i))) + b/z(i))] * sin[π]` (1)

where a, b, c are the parameters of the LICC hyperchaotic system.

The phase diagram of the chaotic system can reflect the distribution of chaotic time series. Just as shown in Fig. 3, when the number of iterations is 50,000, the chaotic sequences generated by LICC is relatively uniform in region D,
`D = {(x, y, z)|x ∈ [−1, 1], y ∈ [−1, 1], z ∈ [-1,1]}`. (2)

Fig. 4 is the distribution of the chaotic sequences generated by LICC hyperchaotic system when three parameters are changed respectively. Here, each parameter is traversed in steps of 0.01 from 0 to 5, and the length of the chaotic sequences is 100, thus there are a total of 50,000 scatters in each graph. It is obviously that the system can stably maintain chaos and evenly distribute in [-1,1] when the parameters change.

#### 2.2.2. Logistic map
To achieve cross-color channel diffusion, the proposed algorithm will randomly group the subpixels of the three color channels in each pixel. After traversing all pixels, the three groups are obtained and then encrypted in parallel. Here, logistic map is introduced for grouping to modularize the pixel grouping and the subsequent encryption processes. Mathematically, logistic map is defined by
`Xn+1 = λ * xn * (1 - xn)`, (3)
when λ ∈ [3.67, 4], it is a chaotic system.

This modular design facilitates debugging and helps identify potential issues during the coding process. Therefore, we use logistic map, which is easy to implement and encode, to control the grouping process.

### 2.3. Reversible data hiding

Reversible Data hiding means insert some useful information into image, and the image can be restored to the original image after the information is extracted. In our ROI image encryption algorithm, the side information of ROI in each patch is crucial for the decryption to be successful. However, delivering this information directly over the Internet increases the risk of leakage and the burden of designing the distribution algorithm. Thus, hiding the side information into the encrypted image and sending them together is a more secure and reasonable option.

Here, a new reversible data hiding scheme proposed by Jia (Jia et al., 2019) is used to hide the side information. Compared with some existing reversible data hiding methods (Chen et al., 2013; Li et al., 2013; Thodi & Rodríguez, 2007; Tsai et al., 2009), it embeds data in the smooth regions of the image, thus reducing the distortion and improving the capacity. The detail process is described as follow.
**Step 1:** As shown in Fig. 5, by ignoring the border pixels, the original image is divided into two parts in a checkerboard pattern, labeled as A and B, respectively. Since the embedding operation in the two parts is the same, only the embedding data in A is described in the following steps.
**Step 2:** First, the local complexity Ωp in part A is calculated as follows.
`Ωp = |P1 - P4| + |P2 - P3| + |P1 + P3 - P2 - P4| + |P3 + P4 - P1 - P2|`.

[Figure 1: The architecture of EDN.]
This figure illustrates the architecture of the Extremely Downsampled Network (EDN).
(a) The overall architecture shows an input Image and its Ground Truth. The image is processed through a 'Backbone' network. The output of the backbone is fed into a series of five parallel processing streams. Each stream consists of a 'C' block followed by an 'SCPC' (Scale-Correlated Pyramid Convolution) block. The outputs are then downsampled and fed into an 'Extremely Downsampled Block'. This block contains a Global Average Pooling layer, a Sigmoid function, and a Global Attention mechanism, which then feeds back to the SCPC blocks. The final output is generated after a 1x1 convolution.
(b) This part details the structure of an SCPC block. An input is passed through a 1x1 convolution and then split. The split paths are processed and then combined through element-wise addition, concatenation, and finally passed through a 3x3 convolution. A legend indicates that 'C' stands for supervision, and other icons represent element-wise multiplication, concatenation, Scale-Correlated Pyramid Convolution, and different types of convolutions (Conv1x1, Conv3x3, Atrous Conv3x3).

[Figure 2: The backbone of lightweight EDN.]
This diagram shows the architecture of the lightweight EDN backbone. It is a sequential flow of blocks starting with 'Conv+BN+ReLu', followed by a series of 'Inverted Residual' blocks. The sequence ends with another 'Conv+BN+ReLu' block. A detailed view of an inverted residual block is shown below the main flow, consisting of 'Conv1x1+BN+ReLu', '3x3 depth-wise convolution+BN+ReLu', and 'Conv1x1+BN'.

[Figure 3: Attractor diagrams of LICC system with initial value (x₀, y₀, z₀) = (0.323690874136891, 1.567982314509317, 0.314829045130345) and a = 3.9, b = π, c = π.]
This figure displays four scatter plots illustrating the behavior of the LICC chaotic system.
(a) A 3D scatter plot showing the overall attractor of the LICC system, which appears as a dense, roughly spherical cloud of points in 3D space.
(b) The projection of the attractor onto the x-y plane. The points are distributed fairly uniformly within a square region from approximately -1 to 1 on both axes.
(c) The projection of the attractor onto the x-z plane, showing a similar uniform distribution within a square.
(d) The projection of the attractor onto the y-z plane, again showing a uniform distribution of points within a square.

[Figure 4: Bifurcation diagram of LICC system initial value (x₀, y₀, z₀) = (0.323690874136891, 1.567982314509317, 0.314829045130345).]
This figure contains three bifurcation diagrams for the LICC system.
(a) Bifurcation diagram with parameter 'a' when b = π and c = π. It shows how the system's state evolves as 'a' varies, demonstrating chaotic behavior across a wide range of 'a'.
(b) Bifurcation with parameter 'b' when a = 3.9 and c = π. The plot shows the system's behavior as 'b' is varied.
(c) Bifurcation with parameter 'c' when a = 3.9 and b = π. The plot shows the system's behavior as 'c' is varied. All diagrams show dense, filled regions, characteristic of chaos.

[Figure 5: Dividing the image in a checkerboard pattern, black pixels are A and white pixels are B.]
This figure shows a grid representing an image divided into a checkerboard pattern. The grid cells are labeled alternately with 'a' and 'b' (e.g., a1, b1, a2, b2, etc.) to illustrate the two sets of pixels, A (black) and B (white), used in the reversible data hiding scheme.

where P₁, P₂, P₃, P₄ are the value of pixels directly adjacent to pixel p: above, left, right, and below, respectively.
Secondly, the calculation of the fluctuation value FΩ of each pixel in part A has three situations, which are one adjacent pixel, two adjacent pixels, and four adjacent pixels. Taking a₁, a₂ and a₄ in Fig. 5 as an example, their fluctuation values are shown below,
`FΩ_a1 = Ω_a1 + Ω_a4`
`FΩ_a2 = Ω_a2 + [(Ω_a1 + Ω_a5)/2]`
`FΩ_a4 = Ω_a4 + [(Ω_a1 + Ω_a2 + Ω_a7 + Ω_a8)/4]` (4)
where `[]` means floor function.
**Step 3:** The computation of prediction error eₚ of each pixel is described below.
**Step 3.1:** First, for pixel p, its prediction value P'ₚ is
`P'ₚ = [ω₁ * P₁ + ω₂ * P₂ + ω₃ * P₃ + ω₄ * P₄]`, (5)
where ω₁, ω₂, ω₃, ω₄ are the weights of {P₁, P₂, P₃, P₄}, respectively, and ω₁ + ω₂ + ω₃ + ω₄ = 1.
**Step 3.2:** The average value P_means of the four adjacent pixels for p is calculated as
`P_means = [(P₁ + P₂ + P₃ + P₄)/4]`. (6)
**Step 3.3:** The difference between the values of the four adjacent pixels for p and P_means is calculated as follows,
`e₁ = P₁ - P_means`
`e₂ = P₂ - P_means`
`e₃ = P₃ - P_means`
`e₄ = P₄ - P_means` (7)
**Step 3.4:** According to e₁, e₂, e₃, e₄, ω'₁, ω'₂, ω'₃, ω'₄ are computed as follows,
`ω'ᵢ = { 1/|eᵢ| if Σ|eⱼ| != 0; 1/|Σ|eⱼ|| otherwise }` (8)
where i ∈ [1,4], and ω₁, ω₂, ω₃, ω₄ are the normalization results of ω'₁, ω'₂, ω'₃, ω'₄ respectively.
The prediction error of pixel p is computed by
`eₚ = Pₚ - P'ₚ` (9)
where Pₚ is the value of pixel p.
**Step 4:** Continue repeating the above process, and all the extracted fluctuation value and prediction error value of each pixel are denoted as F_seq and P_seq, respectively.
**Step 5:** The data to be embedded is encrypted using XOR at the byte level, where the key stream is generated by another independent logistic map. The embedding process is shown in Alg. 1. Here, data[num] means the num-th bit to be embedded and I[i] means the ith pixel in image I.
The extraction of embedded data and the recovery of images are the reverse operations of embedding.

**Algorithm 1 The embedding process**
```
Require: F_seq, P_seq, data, I
Ensure: Image that contains steganography information.
1: function EMBEDDATA(F_seq, P_seq, data, I)
2:   Sort F_seq and P_seq in ascending order, and the sorted sequences are denoted as F'_seq and P'_seq respectively.
3:   Find two peak points PK₁, PK₂ and the nearest zero point Z₁ to their left and the nearest zero point Z₂ to their right from P'_seq.
4:   num ← 0
5:   for i = 0 to len(P_seq) - 1 do
6:     while num < len(data) do
7:       if P'_seq[i] == min(PK₁, PK₂) then
8:         I[i] = data[num].
9:         num ++.
10:      else if P'_seq[i] == max(PK₁, PK₂) then
11:        I[i]+ = data[num].
12:        num ++.
13:      else if Z₁ < P'_seq[i] < min(PK₁, PK₂) then
14:        I[i] -= 1.
15:      else if max(PK₁, PK₂) < P'_seq[i] < Z₂ then
16:        I[i]+= 1.
17:      end if
18:    end while
19:  end for
20: end function
```

### 3. ROI-based image encryption algorithm

Fig. 6(a) depicts the encryption process of our algorithm, which comprises of the detection of sensitive region, parallel encryption and reversible data hiding. The corresponding decryption process has roughly the inverse operations, as shown in Fig. 6(b).

Here, the "semantically enhanced" aspect is applied by integrating lightweight-EDN saliency detection network as shown in Figs. 1 and 2 to identify ROI regions efficiently. This lightweight network captures essential semantic features, such as object significance and spatial relevance, while maintaining low computational complexity. By focusing on the most salient areas in an image, our method balances detection speed with accuracy. Then, with the coordinate information of the detected salient regions, the proposed method enables precise extraction of sensitive region pixels, which are then encrypted and protected. From this perspective, our ROI encryption incorporates semantic enhancement, achieving efficient ROI detection and encryption of sensitive regions.

For ease of reading, Table 2 lists the definition of parameters used in Section 3.

### 3.1. The detection of sensitive region

Let us take Fig. 7(a) as example, the proposed PSRD is introduced as follows.
**Step 1:** Input Fig. 7(a), EDN-lite outputs a binary salient map, as shown in Fig. 7(b), along with the coordinates of each sensitive region in image.
**Step 2:** Sensitive region analysis and detection.
**Case 0:** As shown in Fig. 7(c), obviously, the shape of the white regions can tell us a rough idea of its content, so directly encrypting these pixels cannot ensure the security of sensitive region.

[Figure 6: (a). The flowchart of encryption scheme, (b). The flowchart of decryption scheme.]
This figure presents two flowcharts.
(a) Encryption Scheme: The process starts with a 'Plain-image'. It undergoes 'ROI detection using EDN-lite and PSRD'. This leads to 'Pixel extraction in ROI'. The extracted pixels are split into three color channels (red, green, blue) and encrypted in parallel using respective keys (Key_red, Key_green, Key_blue). The 'ROI auxiliary information' from the detection step is hidden using 'Key_hide' into the 'Image with ciphered ROI' to produce the final 'Image with ciphered ROI and embedded auxiliary information'.
(b) Decryption Scheme: The process starts with the 'Image with ciphered ROI and embedded auxiliary information'. 'ROI auxiliary information extraction' is performed using 'Key_hide'. The three color channels are decrypted in parallel using their respective keys. The decrypted pixels are combined in 'Restoration of pixels in ROI', which is guided by the extracted auxiliary information, to reconstruct the 'Plain-image'.

[Figure 7: (a). Original image, (b). The salient map of (a), (c). Mapping (b) directly to the original image as sensitive region, (d). Covering the salient region in (b) with a rectangular box as sensitive region, (e). Leveraging the PSRD to cover the salient region as sensitive region, (f). The output of PSRD.]
This figure shows a sequence of six images demonstrating the ROI detection process.
(a) The original image showing a zebra and a giraffe.
(b) The binary salient map generated by the detection model, where the animals are highlighted in white against a black background.
(c) The salient map overlaid on the original image, showing which pixels would be selected for direct encryption. This reveals the shapes of the animals.
(d) A large rectangular bounding box drawn to encompass all salient regions. This method includes a lot of non-sensitive background area between the animals.
(e) The result of the proposed PSRD method, which uses smaller, tighter rectangular patches to cover the salient regions, reducing the amount of non-sensitive area included.
(f) The final PSRD output on the original image, showing the selected regions for encryption. This method is a trade-off, being more efficient than the single large box but more secure than encrypting the exact salient shapes.

[Table 2: Function parameter definition in Section 3.]
| Parameter | Definition |
| :--- | :--- |
| I | The plain-image |
| N² | The number of patches segmented by PSRD |
| ROI_info | The side information of sensitive regions |
| pixel_num | The number of pixels to be encrypted |
| T | The number of pre-iterations of LICC and logistic map |
| index'\_seg | The shuffled patch indexes sequence |
| chaoseq_logi | The chaotic sequence generated by logistic map |
| chao₀, chao₁, chao₂ | The chaotic sequences generated by LICC |
| seq₀, seq₁, seq₂ | The pixel sequences to be encrypted |
| cseq₀, cseq₁, cseq₂ | The ciphered pixel sequences |
| dseq₀, dseq₁, dseq₂ | The decrypted pixel sequences |

[Table 3: Pixels allocation rule in encryption stage.]
| | Red | Green | Blue |
| :--- | :--- | :--- | :--- |
| rule0 | seq₀ | seq₁ | seq₂ |
| rule1 | seq₀ | seq₂ | seq₁ |
| rule2 | seq₁ | seq₀ | seq₂ |
| rule3 | seq₁ | seq₂ | seq₀ |
| rule4 | seq₂ | seq₀ | seq₁ |
| rule5 | seq₂ | seq₁ | seq₀ |

[Figure 8: The ROI pixels of an RGB image are assigned to three pixel sequences through a logistic map.]
This diagram illustrates the pixel extraction and grouping process. On the left, a region of interest (ROI) from an image is shown, with colored circles representing pixels. An arrow labeled 'Pixels extraction' points to the right, where the pixels are separated into three distinct sequences. Each sequence consists of one color channel (Red, Green, or Blue) from the original pixels. The diagram demonstrates how the RGB components of each pixel in the ROI are extracted and grouped into three parallel sequences for encryption.

**Case1:** To conceal shape information, a common approach is to obtain the boundary coordinates of the white region (top, bottom, left, and right) in Fig. 7(c), and then extend the white region into a rectangle based on these values as shown in Fig. 7(d). Although encrypting the region in Fig. 7(d) can meet our security requirements, the encryption of some non-sensitive regions (e.g. the regions between two horses) leads to a low encryption efficiency.

Our trade-off detection method first divides the salient map output in Step 1 evenly into N x N patches. If a patch includes white regions, it is considered to include sensitive regions. To further eliminate most of the non-sensitive regions within each patch, our method calculates the minimum value of the upper/left boundary and the maximum value of the lower/right boundary across all white regions. Then, the refined white region is shown in Fig. 7(e). Compared with Figs. 7(c) and (d), it is obvious that our method does not leak the information of the shape of the objects and has no redundant regions. Therefore, the proposed method enables efficient detection and security tagging of sensitive regions.
**Step 3:** The final detection output with PSRD method is shown in Fig. 7(f), and the tag information of sensitive region in each patch is stored in ROI_info, which contains the number of sensitive regions and the top-left and lower-right coordinates of the sensitive region.

### 3.2. The encryption of sensitive regions

#### 3.2.1. Pixel extraction in sensitive regions
Fig. 8 is the schematic of the extraction procedure and the corresponding detailed operations is shown in Alg. 2. It should be noted that each patch has a corresponding index, ranging from 0 to N² – 1. And index'_seg is the sequence of shuffled patch indexes.
First, the number of pixels in sensitive regions pixlenum is calculated according to ROI_info. Then, logistic map is pre-iterated for T times, so that it can enter a chaotic state. Then, logistic map is iterated for pixlenum/3 times to generate chaotic sequence chaoseq_logi. During extraction, the three color components in each pixel is randomly assigned to a sequence according to the allocation rules in Table 3, and the allocation rule of each pixel is determined by chaoseq_logi, as shown in lines 4-6.

#### 3.2.2. Multi-channel parallel encryption
Fig. 9 depicts the parallel encryption process of three extracted pixel data. It should be noted that before parallel encryption, LICC hyperchaotic system is pre-iterated T times to make it enter a chaotic state, and then iterated len(seqⱼ) times to generate chao₀, chao₁, chao₂ to encrypt seq₀, seq₁, seq₂, respectively. The detailed encryption operations in each thread and thread synchronization parameter setting operations are shown in Alg. 3 and Alg. 4.
To further improve the encryption efficiency, the extracted pixels in each thread are encrypted in a simultaneous permutation-diffusion

[Figure 9: The diagram of the multi-channel parallel encryption method.]
This diagram illustrates the parallel encryption process. On the left, three separate sequences of pixels (represented by colored circles) are shown. These sequences are fed into three parallel threads (Thread0, Thread1, Thread2). Each thread diffuses its respective pixel sequence using a chaotic sequence generated by LICC. The output of each thread is a sequence of ciphered pixels (represented by gray circles labeled C1, C2, etc.). Finally, an arrow indicates that these encrypted pixels are placed back into the ROI of the image.

[Figure 10: The diagram of the simultaneous permutation-diffusion.]
This figure illustrates the concept of simultaneous permutation-diffusion.
The top part shows a two-step process: 'Permutation' followed by 'Diffusion'. A sequence of pixels `seq_j` is first reordered (permuted). Then, the permuted sequence is processed one by one (diffused) to create the ciphered sequence `cseq_j`.
The bottom part shows the proposed simultaneous method. For each pixel in the output sequence `cseq_j`, its value is calculated based on a key (`ksele`), a pixel from the original sequence at a permuted location (`seq_j[index[i]]`), and the previously calculated cipher pixel (`cseq_j[i-1]`). The example `cseq_j[5] = en(ksele5, seq_j[index[5]], cseq_j[4])` with `index[5]=9` shows that the permutation (choosing `seq_j[9]`) and diffusion (using `cseq_j[4]`) happen in a single step. This is more efficient as it avoids a separate full pass for permutation.

manner, as shown in Alg. 3. Here, the permutation coordinates are quantized from generated chaotic sequence as shown in lines 3-6. Specifically, the right parts in Fig. 10 depicts the simultaneous permutation-diffusion operations in lines 7-13. It can be seen that the output value of cseqⱼ[i] is determined by the values of current keystream elements ksele, the current plain-pixel seqⱼ[index[i]] and the previous ciphered pixel cseqⱼ[i - 1], respectively. Here, the introduction of permutation coordinates index[i] achieves pixel permutation, while the incorporation of the previous cipher pixel simultaneously realizes the diffusion of the encryption effect. We can also visually observe from Fig. 10 that, in contrast to the upper part of Fig. 10, the strategy employed on the lower part demonstrates higher efficiency by saving one round of pixel data traversal for permutation. Additionally, L is 256 when image I is an RGB image with eight bits per channel.

Alg. 4 demonstrates operations related to thread parameter settings during parallel encryption. Specifically, the _beginthreadex() function from the Windows API is invoked for three times to create the three threads, and the initial state of the three threads is set to suspended. Then the priority and affinity of the three threads and thread arguments (the pixel sequences and pseudo-random chaotic sequences assigned to each thread) are set to make sure that these threads can encrypt each pixel sequence strictly on different processors. Next, the three threads are resumed to begin parallel encryption.

#### 3.2.3. Data steganography
The related information ROI_info and shuffled patch index sequence index'_seg generated in Alg. 2 are declared as integer and hidden into the encrypted image with the method introduced in Section 2.3. Here,

**Algorithm 2 Pixel extraction in sensitive regions**
```
Require: I, ROI_info, N
Ensure: seq₀, seq₁, seq₂, index'_seg
1: function PIXELEXTRACT(I, ROI_info, N)
2:   Calculate the number of pixels pixel_num in sensitive regions according to ROI_info.
3:   Pre-iterate logistic map T times, and then iterate pixel_num/3 times to generate chaotic sequence, chaoseq_logi.
4:   for i = 0 to len(chaoseq_logi) - 1 do
5:     rule[i] ← |chaoseq_logi[i]| × 10¹⁵ mod 6.
6:   end for
7:   flag ← 0, index'_seg ← []
8:   for i = 0 to N x N - 1 do
9:     if flag ∈ index'_seg then
10:      index_seq ← [0,1, ... flag]
11:      flag is changed to the maximum value of set index_seq
12:      index'_seg that is less than the flag, or the minimum value that is greater than the flag.
13:    end if
14:    if ROI_info[flag].num ≠ 0 then
15:      All the ROI pixels of patch[flag] were extracted and randomly assigned to three pixel sequences according to rule.
16:    end if
17:    index'_seg.append(flag)
18:    patch_temp ← patch[i]
19:    flag ← patch_temp[-1][-1][-1] mod (N × N)
20:  end for
21: end function
```

**Algorithm 3 The encryption operations in threadⱼ**
```
Require: chaoⱼ, seqⱼ, j ∈ {0,1,2}
Ensure: cseqⱼ, j ∈ {0,1,2}
1: function ENCRYPTION(chaoⱼ, seqⱼ, j ∈ {0,1,2})
2:   index ← [0, 1, 2..., len(seqⱼ) - 1]
3:   for i = 0 to len(seqⱼ) - 1 do
4:     chaoval ← (int64)(|chaoⱼ[i]| · 10¹⁵)%(len(seqⱼ) – i)
5:     Swap the value of index[chaoval] and index[len(seqⱼ) – 1 – i].
6:   end for
7:   preVal ← (int64)(|chaoⱼ[1]| · 10¹⁵)%L
8:   ksele ← (int64)(|chaoⱼ[0]| · 10¹⁵)%L
9:   cseqⱼ[0] ← ksele ⊕ [(seqⱼ[index[0]] + ksele)%L] ⊕ preVal
10:  for i = 1 to len(seqⱼ) – 1 do
11:    ksele ← (int64)(|chaoⱼ[i]| · 10¹⁵)%L
12:    cseqⱼ[i] ← ksele ⊕ [(seqⱼ[index[i]] + ksele)%L] ⊕ cseqⱼ[i - 1]
13:  end for
14: end function
```

**Algorithm 4 The parallel encryption of extracted pixel data**
```
Require: seqⱼ, chaoⱼ, ROI_info, j ∈ {0,1,2}
Ensure: The ciphered pixel data.
1: function PARALLELENCRYPTION(seqⱼ, chaoⱼ, ROI_info, j ∈ {0,1,2})
2:   Create three threads and suspend them.
3:   Set the affinity and arguments of each thread.
4:   Resume the execution of threads.
5:   spawn
6:     Encryption(chaoⱼ, seqⱼ)
7:   sync
8:   According to ROI_info, write the ciphered pixel data back to image.
9: end function
```

[Table 4: Pixels allocation rule in decryption stage.]
| | seq₀ | seq₁ | seq₂ |
| :--- | :--- | :--- | :--- |
| rule0 | Red | Green | Blue |
| rule1 | Red | Blue | Green |
| rule2 | Green | Red | Blue |
| rule3 | Blue | Red | Green |
| rule4 | Green | Blue | Red |
| rule5 | Blue | Green | Red |

each patch uses 1 bit to indicate sensitive regions: 0 for none, 1 for present. The coordinate information of the sensitive region in each patch need 32 bits to represent, and the index of each patch needs 6 bits to represent.

When embedding data, we first store the above data into an array in units of bits. Then, for the image I in which data is to be embedded, we perform Steps 1 to 4 from Section 2.3 to obtain F_seq and P_seq. Finally, we perform Step 5 and invoke Alg.1 to embed the data into image I.
By using steganography, we add an additional layer of protection to the ROI side information and complete the transmission of all data with just a single data distribution.

### 3.3. Decryption process

The decryption process is roughly the reverse of the encryption process, which contains the extraction of encrypted ROI pixels, the decryption of three ROI pixel sequences in parallel, and the use of the rule in Table 4 to restore these pixels to their original channels. Particularly, the reverse of line 12 in Alg. 3 is given by
`dseqⱼ[index[i]] = [(seqⱼ[i] ⊕ seqⱼ[i - 1] ⊕ ksele) + L – ksele]%L, j ∈ {0,1,2}` (10)
where for an RGB images with eight bits per channel, L = 256.

## 4. Experimental results and security analysis

In experiments, different images are encrypted to test the performance of the proposed ROI encryption method, in which the initial value and parameters of LICC are set to (0.3, 1.5,0.9) and (3.9, π, π) respectively, and N in PSRD method is set to 6 unless otherwise specified.

### 4.1. Key space analysis

In the proposed scheme, the encryption keys, which correspond to the initial values of the LICC system, are randomly assigned by users within the predefined range of the initial values of LICC system. This allows for flexibility while ensuring that the assigned keys meet the necessary conditions for secure encryption. Therefore, the key space contains three double-precision floating-point numbers and each value has 15 bits effective accuracy. As a result, the key space is (10¹⁵)³, which is approximately equal to 2¹⁵⁰ and larger than 2¹⁰⁰. Therefore, the method is secure enough to resist brute force attack (Alvarez & Li, 2006).

### 4.2. Statistical properties analysis

Due to the inherent visual redundancy of images, statistical attacks have evolved into the most common and efficient method for attacking image encryption systems. In this part, histogram analysis, correlation of adjacent pixels analysis and information entropy analysis are used to prove the security of the algorithm when facing statistical attack.

[Figure 11: (a). Original images, (b). ROI before encryption, (c) Histograms of ROI before encryption, (d). ROI after encryption, (e). Histograms of ROI after encryption.]
This figure displays results for four different images: a zebra/giraffe, a bird, a walrus, and a sheep.
(a) The original color images.
(b) The extracted regions of interest (ROI) before encryption. These are irregularly shaped cutouts of the animals from the original images.
(c) The RGB histograms of the ROI before encryption. Each histogram shows distinct peaks and a non-uniform distribution for the red, green, and blue channels.
(d) The ROI after encryption. The original content is replaced with noise-like, random-colored pixels.
(e) The RGB histograms of the ROI after encryption. The histograms for all three color channels are now flat and uniform, spanning the entire range of pixel values, which indicates a successful encryption that has removed statistical patterns.

[Table 5: Information entropy of four plain images and encrypted images.]
| Image | Plain region | Encrypted region |
| :--- | :--- | :--- |
| Zebra & giraffe | 7.4347 | 7.9933 |
| Bird | 6.9003 | 7.9870 |
| Walrus | 7.0042 | 7.9935 |
| Sheep | 7.4948 | 7.9934 |

[Figure 12: (a). Original image, (b). Encrypted image when N is 1.]
This figure shows two images.
(a) The original image of a zebra and a giraffe.
(b) The same image after encryption with N=1 (meaning the entire image is treated as a single ROI). The image is completely obscured by random, colorful noise, making the original content unrecognizable.

#### 4.2.1. Histogram analysis
In order to defend statistical attack, the histogram of the encrypted regions should be as uniform as possible. Fig. 11 shows histograms of the ROI of four images before and after encryption, here, the histograms after encryption are evenly distributed, which demonstrates that the pixel distribution in sensitive region is visually hidden.

#### 4.2.2. Information entropy analysis
Information entropy is used to measure the randomness of an image, which is defined by
`H(x) = − Σ P(xᵢ)log₂(P(xᵢ))` (11)
where, n is the number of pixels and P(xᵢ) is the value of pixel xᵢ. We use images in Fig. 11(a) as test images, whose gray level is 256, so the information entropy of encrypted regions should be close to 8. From Table 5, the information entropy of four encrypted regions are all close to 8, this result is directly linked to the chaotic map employed in our encryption process. The inherent randomness of the LICC and logistic map results in highly unpredictable encryption patterns. Furthermore, our algorithm strategically integrates chaos theory into both the encryption framework, enhancing the system's ability to generate secure and random patterns. As demonstrated by the high entropy values in Table 5, these design choices ensure that the cipher-regions achieves near-maximal randomness and robustness.

#### 4.2.3. Correlation of adjacent pixels analysis
In plain-images, adjacent pixels often exhibit strong correlation, which can be exploited by attackers to infer pixel values. An effective encryption algorithm must have the ability to break this correlation to enhance the randomness and security of the encrypted image, making it more resistant to cryptanalysis (Song, Fu, Lin, et al., 2024). To analysis the correlation of adjacent pixels in encrypted region, just as shown in Fig. 12, we set the N in PSRD method to 1 to get a rectangular ROI and select 1000 pairs of pixels from it randomly.
Fig. 13 shows the visualization of the correlation of horizontal, vertical and diagonal adjacent pixels in ROI in Figs. 12(a) and 12(b), where the red, green and blue dots represent the correlation of the image on the R, G and B components, respectively. For the original image, most points are concentrated near the diagonal of each y-z plane, indicating a strong correlation between adjacent pixels. For the encrypted image, points are distributed in the whole y-z plane evenly, showing that the high correlation of the original image has been broken (Chen et al., 2020; Chen, Guo, et al., 2023; Chen, Wang, et al., 2023; Gong & Luo, 2023).
The correlation coefficients can quantitatively assess the relevance of adjacent pixels, which is shown in Eq. (12).
`r(x, y) = (Σ(xᵢ − E(x))(yᵢ – E(y))) / (sqrt(Σ(xᵢ − E(x))²) * sqrt(Σ(yᵢ − E(y))²))` (12)
where xᵢ, yᵢ are the values of adjacent pixels, N is the number of pixels, E(x) = (1/N)Σxᵢ, and E(y) = (1/N)Σyᵢ.
Table 6 shows the correlation coefficients between the R, G, and B components of the plain-region Fig. 12(a) and the corresponding

[Figure 13: (a), (b), (c) are the scatter diagrams of the horizontal, vertical and diagonal adjacent pixels in ROI of the original image respectively. (d), (e), (f) are the scatter diagrams of the horizontal, vertical and diagonal adjacent pixels in ROI of encrypted image respectively.]
This figure contains six scatter plots showing the correlation between adjacent pixel values.
(a), (b), (c) are for the original image. They show the correlation for horizontally, vertically, and diagonally adjacent pixels. In all three plots, the data points (colored red, green, and blue for the different color channels) are tightly clustered along the main diagonal (y=x), indicating a very high correlation.
(d), (e), (f) are for the encrypted image. They show the correlation for the same sets of adjacent pixels. In these plots, the data points are scattered randomly and uniformly across the entire plotting area, indicating that the correlation between adjacent pixels has been effectively eliminated by the encryption process.

[Table 6: Correlation coefficients of the plain-image and the corresponding cipher-image.]
| Direction | Plain region | | | Encrypted region | | |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| | R | G | B | R | G | B |
| Horizontal | 0.822613 | 0.848189 | 0.817465 | 0.013102 | 0.035463 | 0.016454 |
| Vertical | 0.851788 | 0.872268 | 0.821505 | 0.004168 | 0.004498 | -0.018506 |
| Diagonal | 0.735205 | 0.772554 | 0.719809 | 0.043012 | 0.012318 | 0.015241 |

[Table 7: Result of NPCR and UACI tests.]
| NPCR | UACI |
| :--- | :--- |
| 99.5759% | 33.3449% |

[Table 8: Different secret keys.]
| | x₀ | y₀ | z₀ |
| :--- | :--- | :--- | :--- |
| key₁ | 0.323690874136891 | 1.567982314509317 | 0.314829045130345 |
| key₂ | 0.323690874136892 | 1.567982314509317 | 0.314829045130345 |
| key₃ | 0.323690874136891 | 1.567982314509318 | 0.314829045130345 |
| key₄ | 0.323690874136891 | 1.567982314509317 | 0.314829045130346 |

cipher-region Fig. 12(b) in the horizontal, vertical, and diagonal directions. From this table, we find that the correlation in encrypted image is close to 0, which implies our method can decorrelate the strong correlation in each cipher region. The low correlation between adjacent pixels in these cipher-regions stems from the integration of chaos theory and our cross-color channel encryption design. These features disrupt spatial relationships, ensuring the cipher-regions effectively obscure patterns and enhances security.

### 4.3. Differential attack

In order to resist differential attack, two images with only minor differences should be completely different after encryption. NPCR (the number of pixel change rate) and UACI (the unified average changing intensity) are two criteria for measuring the difference between two regions with the same size. For the image whose gray level is 256, the theoretical values of NPCR and UACI are 99.609% and 33.464%, respectively (Guo et al., 2024). As shown in Fig. 11, our detection results always have irregular regions, but measuring the difference between them is complex. As previously described, during the encryption process, we extract the pixels from the irregular ROI regions into a one-dimensional array. Therefore, we perform an equivalent transformation of NPCR and UACI to measure the difference between two one-dimensional arrays. The transformed formulas are as follows:
`NPCR = (Σ(D(i))/L) × 100%` (13)
`UACI = (1/L) * Σ(|P₁(i) - P₂(i)|/255) × 100%` (14)
where L is the length of the array, P₁(i) and P₂(i) are the values of the two arrays at position i, and
`D(i) = {0 if P₁(i) = P₂(i); 1 if P₁(i) ≠ P₂(i)}` (15)

We use secret key to encrypt Fig. 12(a), then, the pixel value of (37, 21) in Fig. 12(a) is added by one and the new image is encrypted with the same key, last, calculate the NPCR and UACI of ROI in two encrypted images. The test result is shown in Table 7, which is close to the theoretical values.

### 4.4. Key sensitive analysis

An excellent encryption algorithm should be sensitive to secret key, which means a minor change in the key should produce a completely different result.

#### 4.4.1. Encryption key sensitive analysis
Four keys listed in Table 8 are used to encrypt Fig. 12(a), here, different keys only have minor different in the least significant bit.
We use key₂, key₃ and key₄ as modified keys, and calculate NPCR and UACI between the encrypted region encrypted by modified keys and the encrypted region encrypted by key₁. Just as shown in Table 9, the regions produced by different keys are completely different.

[Table 9: Key sensitive analysis of encryption process.]
| | NPCR | UACI |
| :--- | :--- | :--- |
| key₁ & key₂ | 99.6116% | 33.3105% |
| key₁ & key₃ | 99.6409% | 33.5311% |
| key₁ & key₄ | 99.5835 | 33.3671% |

[Figure 14: (a), (b), (c) are the decrypted results using key₂, key₃ and key₄ respectively.]
This figure contains three images. Each image is the result of attempting to decrypt an encrypted image using a key that is slightly different from the correct one (key₂, key₃, and key₄ from Table 8). All three resulting images, (a), (b), and (c), are completely garbled and appear as random noise, with no discernible features of the original image. This demonstrates the high sensitivity of the decryption process to the secret key.

[Table 10: Comparison of computational efficiency.]
| Network | Params(M) | FLOPs(G) |
| :--- | :--- | :--- |
| YOLOv3 (Redmon & Farhadi, 2018) | 61.5 | 193.9 |
| YOLOv4 (Bochkovskiy et al., 2020) | 52.5 | 119.8 |
| U2Net (Qin et al., 2020) | 44.0 | 235.3 |
| EDN (Wu, Liu, Zhang, et al., 2022) | 42.8 | 56.7 |
| MobileSal (Wu, Liu, Xu, et al., 2022) | 3.5 | 4.1 |
| EDN-lite | 1.8 | 3.1 |

[Table 11: The proportion of the ROI to the entire image.]
| Methods | The percentage of ROI |
| :--- | :--- |
| Singh, Singh, et al. (2022) | 55.18% |
| Sheela and Suresh (2024) | |
| Asgari-Chenaghlu et al. (2021) | |
| Song et al. (2022) | 30.88% |
| PSRD(N=2) | 30.50% |
| PSRD(N=4) | 25.46% |
| PSRD(N=6) | 25.36% |

[Table 12: Comparison of ROI detection accuracy.]
| Method | Fβ ↑ | MAE ↓ |
| :--- | :--- | :--- |
| MobileNetV2 (Sandler et al., 2018) | 0.798 | 0.070 |
| ShuffleNetV2 (Ma et al., 2018) | 0.789 | 0.071 |
| SAMNet (Liu et al., 2021) | 0.835 | 0.058 |
| EDN-lite | 0.862 | 0.045 |

[Table 13: Comparison of encryption time(ms) between parallel and serial processing.]
| Image size | Parallel manner | Serial manner | Acceleration percentage |
| :--- | :--- | :--- | :--- |
| 256 x 256 x 3 | 6.74 | 8.22 | 18.00% |
| 512 x 512 x 3 | 18.40 | 33.44 | 44.97% |
| 1024 x 1024 x 3 | 76.48 | 167.09 | 54.22% |

MAE measures the difference between the predicted result P and the ground truth G, which are defined as,
`Fβ = ((1 + β²) * Precision * Recall) / (β² * Precision + Recall)` (16)
`MAE(P, G) = (1/HW) * ΣΣ|Pᵢⱼ - Gᵢⱼ|` (17)
where β² is set to 0.3. It can be seen that EDN-lite has higher accuracy.

#### 4.4.2. Decryption key sensitive analysis
In decryption process, key₂, key₃ and key₄ listed in Table 8 are used to decrypt the image encrypted by key₁. Just as shown in Fig. 14, all keys cannot decrypt correctly, which means our algorithm is sensitive to secret key.

### 4.5. Comparison of performance with the SOTA methods

#### 4.5.1. Comparison of ROI detection efficiency
As shown in Table 10, the detection efficiency of EDN-lite is compared with YOLOv3 used in Asgari-Chenaghlu et al. (2021), Sheela and Suresh (2024), Singh, Singh, et al. (2022) and YOLOv4 used in Song et al. (2022) and some SOTA deep SOD methods, such as U2Net (Qin et al., 2020), EDN (Wu, Liu, Zhang, et al., 2022) and even lightweight RGB-D SOD MobileSal (Wu, Liu, Xu, et al., 2022). It can be seen that EDN-lite has fewer model parameters and achieves reduced FLOPS.

Furthermore, the detected ROI should be as small as possible while ensuring the security to improve encryption efficiency. Table 11 reports the percentage of detected ROI in the entire image as shown in Fig. 15. We can see that the ROI generated by proposed PSRD is much less than other methods, demonstrating that our detection method can reduce the data to be encrypted and improve the encryption efficiency in the subsequent encryption stage.

The above analyses shows that our proposed method effectively optimizes the regions detected by EDN-lite with different values of N. This unique combination of fine-grained sensitive regions and preserved efficiency makes EDN-lite, when integrated with our PRSD approach, an optimal solution for encryption-oriented applications.

#### 4.5.2. Comparison of ROI detection accuracy
In our ROI detection method, the accuracy is determined by EDN-lite and its performance is compared with some classic SOD models. Here, the dataset is DUTS (Wang et al., 2017), and the training is conducted using Adam optimizer with parameters β₁ = 0.9, β₂ = 0.99, weight decay 10⁻⁴ and batch size is 24. Table 12 illustrates the test results of EDN-lite and some other lightweight networks on DUTS-TE. Here, Fβ is the weighted harmonic mean of precision and recall and

#### 4.5.3. Encryption efficiency analysis
Table 13 reports the encryption time for three rounds of encryption between parallel and serial processing for images of varying sizes. The comparison results demonstrate that the parallel approach achieves a shorter runtime compared to the serial approach. And we can observe that as the data size increases, the acceleration effect becomes more pronounced. Therefore, the proposed algorithm is particularly suitable for encrypting sensitive regions in high-resolution images.

Table 14 shows the comparison results of encryption efficiency when image size is 3MN, here, iteration of chaotic system, its time series quantization, and permutation and diffusion operations are three main time-consuming parts. In our work, permutation and diffusion are operated at the same time, and three threads encrypt pixel sequence in parallel, thus the time complexity is O(MN), which is faster than the other three state-of-the-art algorithms. It is noted that in Wang et al. (2023), diffusion operation contains global diffusion and crossover random diffusion, therefore, the time complexity is O(6MN). From the table, it is obvious that the proposed algorithm provides the best efficiency.

#### 4.5.4. Comparison of security performance with the SOTA methods
Table 15 lists the performance comparison between our work and other SOTA (state-of-the-art) encryption algorithms. Since the number of pixels encrypted in ROI is relatively small, there is a slight gap between our test results and the SOTA methods. To begin with, the previous performance tests have demonstrated that our algorithm can theoretically fulfill the security requirements. In addition, Tables 11 and 14 indicate the efficiency advantage of our work.

[Figure 15: (a). Original image. (b). ROI generated by YOLOv3 in Singh, Singh, et al. (2022). (c). ROI generated by modified YOLOv4 in Song et al. (2022). (d). ROI generated by PSRD(N = 2). (e). ROI generated by PSRD(N = 4). (f). ROI generated by PSRD(N = 6).]
This figure compares different ROI detection methods on an image of a person with two white horses.
(a) The original image.
(b) ROI from YOLOv3: A single large blue bounding box covers the person and both horses, including a significant amount of background.
(c) ROI from modified YOLOv4: Three separate bounding boxes are drawn, one for the person (purple) and one for each horse (green), which are tighter than the YOLOv3 box but still rectangular.
(d) ROI from the proposed PSRD with N=2: The ROI is covered by four large red rectangular patches.
(e) ROI from PSRD with N=4: The ROI is now covered by a larger number of smaller red rectangular patches, fitting the subjects more tightly.
(f) ROI from PSRD with N=6: The ROI is covered by an even larger number of even smaller red patches, providing the tightest fit among the PSRD examples and minimizing the inclusion of non-sensitive background.

[Table 14: Comparison of time complexity.]
| Methods | Keystream generation | Permutation operation | Diffusion operation |
| :--- | :--- | :--- | :--- |
| | **Permutation stage** | **Diffusion stage** | |
| Our work | Θ(3MN) | Θ(MN) |
| Wang et al. (2023) | Θ(3MN) | Θ(3MN) | Θ(6MN) |
| Singh, Singh, et al. (2022) | Θ(3MN) | Θ(3MN) | Θ(3MN) |
| Asgari-Chenaghlu et al. (2021) | Θ(3MN) | Θ(3MN) | Θ(3MN) |
| Song et al. (2022) | Θ(3MN) | Θ(3MN) | Θ(3MN) |

[Table 15: Comparison of security performance with the SOTA methods.]
| Methods | Information entropy of cipher-regions | Correlation coefficients of cipher-regions | | | NPCR | UACI |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| | | **Horizontal** | **Vertical** | **Diagonal** | | |
| Our work | 7.9918 | 0.014518 | -0.009898 | 0.011530 | 99.600% | 33.469% |
| Wang et al. (2023) | 7.9993 | -0.000215 | -0.000045 | 0.000037 | 99.609% | 33.464% |
| Singh, Singh, et al. (2022) | 7.9881 | 0.008400 | 0.019967 | -0.012270 | 99.626% | 33.449% |
| Asgari-Chenaghlu et al. (2021) | 7.9977 | -0.002130 | 0.001350 | 0.003140 | 99.717% | 33.519% |
| Song et al. (2022) | 7.9906 | -0.001132 | 0.002418 | -0.000632 | 99.392% | 33.380% |

[Table 16: The embedding capacity of each image and the size of ROI side information under different values of N in our method, both measured in bits.]
| | Capacity | N = 2 | N = 4 | N = 6 |
| :--- | :--- | :--- | :--- | :--- |
| Zebra & giraffe | 17,690 | 156 | 368 | 924 |
| Bird | 64,279 | 124 | 336 | 572 |
| Walrus | 21,743 | 156 | 400 | 860 |
| Sheep | 36,914 | 156 | 432 | 796 |

[Table 17: The test results of visual hiding quality.]
| | PSNR | MSSIM |
| :--- | :--- | :--- |
| Zebra & giraffe | 69.86 dB | 0.9999 |
| Bird | 79.24 dB | 0.9999 |
| Walrus | 77.04 dB | 0.9999 |
| Sheep | 79.48 dB | 0.9999 |

### 4.6. Image steganography and ROI side information protection analysis

#### 4.6.1. Image steganography analysis
Here, we conduct embedding capacity experiments to verify whether there is sufficient capacity to embed the ROI side information. Table 16 presents the embedding capacity of each image and the size of ROI side information under different values of N, both measured in bits. It can be observed that the spatial capacity of each image is sufficient enough to accommodate the embedding of ROI side information within our proposed method.
An effective steganographic algorithm should ensure that the image remains virtually unchanged before and after data embedding. The PSNR (Peak Signal-to-Noise Ratio) and MSSIM (Mean Structural Similarity Index) comparison results of images before and after embedding are presented in Table 17. Mathematically, the two metrics are defined as follows.
`MSE = (1/MN) * ΣΣ(P(i, j) – I(i, j))²` (18)
`PSNR = 10log₁₀((255 * 255) / MSE)`
`MSSIM = (2(μ_p * μ_I + C₁)(2σ_pI + C₂)) / ((μ_p² + μ_I² + C₁)(σ_p² + σ_I² + C₂)) * (Pk, Ik)` (19)
where, μ_p, μ_I, σ_p and σ_I are the mean value and the standard deviation of two images, respectively. C₁ and C₂ are used to prevent the denominator from becoming zero, which are set to 6.5 and 58.5. From Table 17, it can be seen that PSNR is greater than 40 dB and MSSIM is close to 1, it can be stated that the two images are basically identical (Ye & Guo, 2024). The main reason is that the amount of data to be embedded is relatively small and is embedded only in the least significant bit of each pixel, resulting in minimal impact on visual quality.

#### 4.6.2. ROI side information protection analysis
Table 18 illustrates the data distribution cost under scenarios with/without ROI side information hiding. It is evident that distributing extra ROI side information adds to the data transmission burden. Our steganographic mechanism not only avoids this issue but also adds an additional layer of protection to the encryption scheme. Moreover, as the volume of images increases, the savings in distribution costs become even more substantial.

### 4.7. Limitations

Our scheme is designed for the encryption of ROI within a single image. When encrypting the ROI of multiple images, there are certain limitations in achieving diffusion of the encryption effect across different ROI. And the number of iterations of a chaotic system in the proposed scheme is equal to the number of pixels to be encrypted. Therefore, the iteration process is time consuming when encrypting multiple images.

## 5. Conclusion and future work

In this paper, we propose a semantic-based image encryption algorithm to protect the ROI of the image. First, our detection method considers the security of image information and the area of the ROI comprehensively, which minimizes the encryption area as much as possible while ensuring that the image information is not leaked. Then, the pixels are allocated to three different pixel sequences randomly and encrypted in parallel to improve efficiency. After that, ROI side information is embedded into the whole image using reversible data hiding. The experimental results and security analyses show that our proposed encryption scheme is secure and convenient.

The choice of the value for N in the proposed PSRD requires further exploration, as there may be an optimization problem involved. When N is set to the optimal value, the best-optimized ROI region can be achieved. Compared to CNN-based object detection networks, studies (Han et al., 2022; Khan et al., 2022) have shown that ViT(Vision Transformer)-based models achieve higher accuracy. However, ViTs are relatively inefficient (Zheng et al., 2023). Developing an ROI encryption algorithm based on lightweight ViT for object detection is an important direction for future research.

---

**CRediT authorship contribution statement**

**Buyu Liu:** Conceptualization, Methodology, Software, Writing – review & editing. **Wei Song:** Conceptualization, Methodology, Software, Writing - review & editing. **Mingyi Zheng:** Conceptualization, Writing – review & editing. **Chong Fu:** Conceptualization, Methodology, Writing - review & editing. **Junxin Chen:** Methodology, Writing – review & editing. **Xingwei Wang:** Writing - review & editing.

---

**Declaration of competing interest**

The authors declare that they have no known competing financial interests or personal relationships that could have appeared to influence the work reported in this paper.

---

**Acknowledgments**

This research is supported by the National Natural Science Foundation of China (Nos. 62171114 and 62032013), the Fundamental Research Funds for the Central Universities, China (Nos. N2424010-18 and N2316010), Liaoning Provincial Science and Technology Plan Project, China (2023JH2/101700370), and the Joint Funds of Natural Science Foundation of Liaoning Province, China (No. 2023-BSBA-121).

---

**Data availability**

Data will be made available on request.

---

[Table 18: Comparison of data distribution costs (KB) with and without ROI side information hiding.]
| Image | With hiding | | Without hiding | |
| :--- | :--- | :--- | :--- | :--- |
| | **Cipher-image** | **ROI side information** | **Cipher-image** | **ROI side information** |
| Zebra & giraffe | 306.28 | 0 | 306.28 | 1.13 |
| Bird | 306.28 | 0 | 306.28 | 0.78 |
| Walrus | 306.28 | 0 | 306.28 | 1.06 |
| Sheep | 306.28 | 0 | 306.28 | 1.00 |

---

### References
*Alvarez, G., & Li, S. (2006). Some basic cryptographic requirements for chaos-based cryptosystems. International Journal of Bifurcation and Chaos, 16(08), 2129-2151.*
*Asgari-Chenaghlu, M., Feizi-Derakhshi, M.-R., Nikzad-Khasmakhi, N., Feizi-Derakhshi, A.-R., Ramezani, M., Jahanbakhsh-Nagadeh, Z., Rahkar-Farshi, T., Zafarani-Moattar, E., Ranjbar-Khadivi, M., & Balafar, M.-А. (2021). Cy: Chaotic yolo for user intended image encryption and sharing in social media. Information Sciences, 542, 212-227.*
*Balasamy, K., & Suganyadevi, S. (2021). A fuzzy based ROI selection for encryption and watermarking in medical image using DWT and SVD. Multimedia Tools and Applications, 80, 7167-7186.*
*Bochkovskiy, A., Wang, C.-Y., & Liao, H.-Y. M. (2020). YOLOv4: Optimal speed and accuracy of object detection. ArXiv, arXiv:2004.10934.*
*Cai, C., Wang, Y., Cao, Y., Sun, B., & Mou, J. (2024). Multiple remote sensing image encryption scheme based on saliency extraction and magic cube circular motion. Applied Intelligence: The International Journal of Artificial Intelligence, Neural Networks, and Complex Problem-Solving Technologies, 5944-5960.*
*Chen, J., Chen, L., & Zhou, Y. (2020). Cryptanalysis of a DNA-based image encryption scheme. Information Sciences, 520, 130-141.*
*... (and so on for all references)*