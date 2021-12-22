library(tidyverse)
library(data.tree)

prob_data <- read_csv("probabilities.csv")

make_my_tree <- function(mydf = prob_data, branch_levels = NULL, show_rank = TRUE, direction = "LR",  root_name = "Start", font_name = 'helvetica') {

  mydf <- mydf %>%  mutate(tree_level = str_count(string = pathString, pattern = "/") + 1,
           tree_group = str_replace(string = pathString, pattern = "/.*", replacement = ""),
           node_type = "decision_node")
  
  max_tree_level <- max(mydf$tree_level, na.rm = T) 
  
  parent_lookup <- mydf %>% distinct(pathString, prob) # get distinct probabilities to facilitate finding parent node probability
  
  for (i in 1:(max_tree_level -  1)) { # loop through all tree layers to get all immediate parent probabilities (to calculate cumulative prob)
    
    names(parent_lookup)[1] <-paste0("parent",i)
    names(parent_lookup)[2] <-paste0("parent_prob",i)
    
    for (j in 1:i) {
      
      if (j == 1)  mydf[[paste0("parent",i)]] <- sub("/[^/]+$", "", mydf$pathString)
      else if (j  > 1) mydf[[paste0("parent",i)]] <- sub("/[^/]+$", "", mydf[[paste0("parent",i)]])
    }
    
    mydf <- mydf %>% left_join(parent_lookup, by = paste0("parent",i))
    
  }
  
  mydf$overall_prob <- apply(mydf %>% select(contains("prob"))  , 1, prod, na.rm = T)  # calculate cumulative probability  
  
  terminal_data <- mydf %>%  filter(tree_level == max_tree_level) %>% # create new rows that will display terminal/final step calculations on the tree
    mutate(node_type = 'terminal',
           pathString = paste0(pathString, "/overall"),
           prob = NA,
           tree_level = max_tree_level + 1)
  
  start_node <- root_name # name the root node
  
  mydf = bind_rows(mydf, terminal_data) %>%  # bind everything together 
    mutate(pathString = paste0(start_node,"/",pathString),
           overall_prob = ifelse(node_type == 'terminal', overall_prob, NA),
           prob_rank = rank(-overall_prob, ties.method = "min", na.last = "keep"))
  
  mydf = bind_rows(mydf, data.frame(pathString = start_node, node_type = 'start', tree_level = 0)) %>% # add one new row to serve as the start node label
    select(-contains("parent"))
  
    if (!is.null(branch_levels) ) {
      mydf <- mydf %>% filter(tree_level <= branch_levels)
      
    }
    
  mytree <- as.Node(mydf) 
  
  GetEdgeLabel <- function(node) switch(node$node_type, node$prob)
  
  GetNodeShape <- function(node) switch(node$node_type, start = "box", node_decision = "circle", terminal = "none")
  
  
  GetNodeLabel <- function(node) switch(node$node_type, 
                                        terminal = ifelse(show_rank  == TRUE, paste0("Prob: ", node$overall_prob,"\nRank: ", node$prob_rank),
                                                          paste0("Prob: ", node$overall_prob)),
                                        node$node_name)
  
  SetEdgeStyle(mytree, fontname = font_name, label = GetEdgeLabel)
  
  SetNodeStyle(mytree, fontname = font_name, label = GetNodeLabel, shape = GetNodeShape)
  
  SetGraphStyle(mytree, rankdir = direction) 
  
  plot(mytree)
  
}


