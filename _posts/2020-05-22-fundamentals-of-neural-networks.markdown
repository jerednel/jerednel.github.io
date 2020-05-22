---
layout: post
title:  "Fundamentals of Artificial Neural Networks"
date:   2020-05-22 16:31:06 -0500
categories: ai
---

This post serves as a growing summary of the fundamentels of artificial neural networks.  
I will add to it to expand on previous to contain the information to a single post rather
than have numerous posts floating around disconnected from each other.

## Artificial Neural Networks - Fundamentals

A neuron is at the heart of an artificial neural network.  A neuron receives signals from
set of input neurons.  You can think of the input layers of a neural network as similar 
to your input senses such as sight, scent, or smell.  Input layer neurons are independent 
variables that we feel may be relevant to the problem we are trying to solve.

The input neuron values are *weighted*.  These weights are what get adjusted as we iterate
through our artificial neural network.

The neuron must figure out how to handle these input neurons and make sense of this data. 
The act of "making sense" of the input neurons is a function that produces an output.  The first
step is to sum the values of the weighted input values.  After this, we apply what is called
an *activation function* to this summary value.


As the signals pass from the input layer through the neuron's activation function and get transformed and pushed to
an output, that output serves as the output of a single observation.  So all rows/observations
in your data set are passed through the neuron sequentially.


## Activation Functions
